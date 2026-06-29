// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PraetorGuard} from "../src/PraetorGuard.sol";

/// @notice Deploy + configure the guard on Base Sepolia.
/// @dev Nothing is broadcast without `--broadcast`. The production wiring (policy/allowlist derived
///      from the compiled spec) is Phase-2's compile(); this script uses the example-spec values.
///      Run: forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC --account <keystore> [--broadcast]
contract Deploy is Script {
    // praetor.spec.yaml example values (USD caps in 1e8)
    uint256 internal constant PER_TX_USD = 5_000e8;
    uint256 internal constant ROLLING_24H_USD = 25_000e8;
    uint16 internal constant MAX_SLIPPAGE_BPS = 50;
    uint16 internal constant MAX_TX_PER_HOUR = 20;

    // Base mainnet addresses from praetor.spec.yaml. Base Sepolia differs — override before a real deploy.
    address internal constant UNIV3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address internal constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    // Selectors computed from canonical signatures — verify against the live ABI before mainnet.
    bytes4 internal constant EXACT_INPUT_SINGLE =
        bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))"));
    bytes4 internal constant EXACT_INPUT = bytes4(keccak256("exactInput((bytes,address,uint256,uint256))"));
    bytes4 internal constant AAVE_SUPPLY = bytes4(keccak256("supply(address,uint256,address,uint16)"));
    bytes4 internal constant AAVE_WITHDRAW = bytes4(keccak256("withdraw(address,uint256,address)"));

    function run() external returns (PraetorGuard guard) {
        address account = vm.envOr("PRAETOR_ACCOUNT", msg.sender); // agent smart account (placeholder = deployer)
        bytes32 specHash = vm.envOr("PRAETOR_SPEC_HASH", keccak256("praetor.spec.yaml@v1"));

        vm.startBroadcast();
        guard = new PraetorGuard(msg.sender, account);
        guard.setPolicy(specHash, PER_TX_USD, ROLLING_24H_USD, MAX_SLIPPAGE_BPS, MAX_TX_PER_HOUR);
        guard.setAllowed(UNIV3_ROUTER, EXACT_INPUT_SINGLE, true);
        guard.setAllowed(UNIV3_ROUTER, EXACT_INPUT, true);
        guard.setAllowed(AAVE_V3_POOL, AAVE_SUPPLY, true);
        guard.setAllowed(AAVE_V3_POOL, AAVE_WITHDRAW, true);
        guard.setHalted(false);
        vm.stopBroadcast();

        console2.log("PraetorGuard deployed:", address(guard));
        console2.log("owner:", guard.owner());
        console2.log("account:", guard.account());
    }
}
