// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/// @title ChainlinkPriceAdapter
/// @notice Prices a token `amount` in USD (1e8) via a Chainlink feed. A stale or invalid round is a
///         BLOCK (revert), never a pass (plan §4.4, CLAUDE.md rule #4).
/// @dev Phase-1: built + fork-tested but NOT imported by PraetorGuard (the caller supplies valueUsd).
///      It exists so the deferred ERC-7579 hook can price calls trustlessly from real calldata.
///      Decimals are explicit (rule #6): token.decimals() and feed.decimals() are cached at setFeed
///      time and never read live — decimals() is optional in ERC-20 and an untrusted target could
///      revert or lie (DoS / mispricing). Feed composition (TOKEN/ETH × ETH/USD) and the Base L2
///      sequencer-uptime check are deferred (all Phase-1 demo assets have direct /USD feeds); see
///      docs/threat-model.md before any mainnet use.
contract ChainlinkPriceAdapter {
    error NotOwner();
    error ZeroAddress();
    error FeedNotSet(address token);
    error StaleRound();
    error IncompleteRound();
    error NonPositiveAnswer();
    error FuturePrice();

    event FeedSet(address indexed token, address indexed feed, uint32 maxStalenessSec);
    event FeedRemoved(address indexed token);
    event OwnershipTransferred(address indexed from, address indexed to);

    struct FeedConfig {
        IAggregatorV3 feed;
        uint8 tokenDecimals; // cached at setFeed time
        uint8 feedDecimals; // cached at setFeed time (Chainlink USD feeds are 8, but never hardcode it)
        uint32 maxStalenessSec;
        bool set; // fail-closed sentinel: unregistered token => revert
    }

    address public owner;
    mapping(address token => FeedConfig) private _feeds;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    /// @dev Reads + caches both decimals via a high-level call: an operator typo (a token without
    ///      decimals(), a non-contract address) reverts here, at registration, not in the hot path.
    function setFeed(address token, address feed, uint32 maxStalenessSec) external onlyOwner {
        uint8 td = IERC20Decimals(token).decimals();
        uint8 fd = IAggregatorV3(feed).decimals();
        _feeds[token] = FeedConfig(IAggregatorV3(feed), td, fd, maxStalenessSec, true);
        emit FeedSet(token, feed, maxStalenessSec);
    }

    function removeFeed(address token) external onlyOwner {
        delete _feeds[token];
        emit FeedRemoved(token);
    }

    function feedOf(address token) external view returns (FeedConfig memory) {
        return _feeds[token];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice `amount` of `token` (in token decimals) -> USD with 8 decimals.
    /// @dev Math: usd1e8 = amount * answer * 1e8 / (10^tokenDecimals * 10^feedDecimals).
    ///      Multiply before divide (single trailing division = one truncation point); checked 0.8.24
    ///      math reverts on absurd overflow (fail-closed). The general *1e8 form keeps a non-8-dp feed
    ///      correct without special-casing.
    function priceToUsd(address token, uint256 amount) external view returns (uint256 usd1e8) {
        FeedConfig memory c = _feeds[token];
        if (!c.set) revert FeedNotSet(token);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = c.feed.latestRoundData();
        // freshness: any failure is a BLOCK
        if (answer <= 0) revert NonPositiveAnswer();
        if (updatedAt == 0) revert IncompleteRound();
        if (answeredInRound < roundId) revert StaleRound();
        if (updatedAt > block.timestamp) revert FuturePrice();
        if (block.timestamp - updatedAt > c.maxStalenessSec) revert StaleRound();

        uint256 answerU = uint256(answer);
        usd1e8 = (amount * answerU * 1e8) / (10 ** uint256(c.tokenDecimals) * 10 ** uint256(c.feedDecimals));
    }
}
