// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPraetorGuard
/// @notice Minimal policy guard interface (plan §6.1). Reverts any out-of-spec call.
/// @dev Phase 1 wires this as an ERC-7579 hook/validator module on a ZeroDev Kernel
///      account (ADR-0001). Events are the audit log: the dashboard and scorecard
///      reconstruct every decision from `Blocked` / `Executed`.
interface IPraetorGuard {
    struct Policy {
        bytes32 specHash;        // commits which spec is in force
        uint256 perTxUsd;        // 1e8 fixed-point
        uint256 rolling24hUsd;
        uint16 maxSlippageBps;
        uint16 maxTxPerHour;
        bool halted;             // circuit breaker
    }

    /// @dev called by the account before executing a call
    function check(
        address target,
        bytes4 selector,
        uint256 valueUsd,        // priced by on-chain oracle adapter
        address recipient,
        uint256 minOut,          // for slippage enforcement
        uint256 quotedOut
    ) external returns (bool);

    function setHalted(bool halted) external; // kill switch (owner only)

    function isAllowed(address target, bytes4 selector) external view returns (bool);
    function isRecipientAllowed(address recipient) external view returns (bool);

    event Blocked(bytes32 indexed specHash, address target, bytes4 selector, string reason);
    event Executed(bytes32 indexed specHash, address target, bytes4 selector);
}

/// @notice Skeleton implementation.
/// @dev TODO(phase1): implement enforcement (allowlist · per-tx & rolling caps ·
///      slippage min-out · rate limit · kill switch) + Chainlink pricing adapter,
///      and the fuzz/invariant suite proving out-of-spec => revert (plan §6.1, §11).
contract PraetorGuard is IPraetorGuard {
    error NotImplemented();

    Policy public policy;
    mapping(address target => mapping(bytes4 selector => bool)) private _allowed;
    mapping(address recipient => bool) private _recipientAllowed;

    function check(address, bytes4, uint256, address, uint256, uint256)
        external
        pure
        returns (bool)
    {
        revert NotImplemented();
    }

    function setHalted(bool) external pure {
        revert NotImplemented();
    }

    function isAllowed(address target, bytes4 selector) external view returns (bool) {
        return _allowed[target][selector];
    }

    function isRecipientAllowed(address recipient) external view returns (bool) {
        return _recipientAllowed[recipient];
    }
}
