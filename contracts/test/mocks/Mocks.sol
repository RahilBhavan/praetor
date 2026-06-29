// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAggregatorV3, IERC20Decimals} from "../../src/ChainlinkPriceAdapter.sol";

/// @notice Settable Chainlink aggregator for deterministic freshness/decimals tests. No framework.
contract MockAggregator is IAggregatorV3 {
    uint8 public decimals;
    uint80 internal _roundId;
    int256 internal _answer;
    uint256 internal _updatedAt;
    uint80 internal _answeredInRound;

    constructor(uint8 d) {
        decimals = d;
    }

    function set(uint80 roundId_, int256 answer_, uint256 updatedAt_, uint80 answeredInRound_) external {
        _roundId = roundId_;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = answeredInRound_;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}

/// @notice Minimal token exposing only decimals() — all the adapter caches.
contract MockERC20 is IERC20Decimals {
    uint8 public decimals;

    constructor(uint8 d) {
        decimals = d;
    }
}
