// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkPriceAdapter} from "../src/ChainlinkPriceAdapter.sol";
import {MockAggregator, MockERC20} from "./mocks/Mocks.sol";

/// @notice Adapter tests: decimals math (token vs feed vs 1e8 USD) + Chainlink freshness (stale = BLOCK).
contract ChainlinkPriceAdapterTest is Test {
    ChainlinkPriceAdapter internal adapter;
    MockERC20 internal usdc; // 6 decimals
    MockERC20 internal weth; // 18 decimals
    MockERC20 internal dai; // 18 decimals (paired with an 18-dp feed to prove feedDecimals isn't hardcoded)
    MockAggregator internal usdcFeed; // 8 dp, $1.00
    MockAggregator internal wethFeed; // 8 dp, $3000
    MockAggregator internal daiFeed; // 18 dp, $1.00

    uint32 internal constant STALE = 3600;

    function setUp() public {
        vm.warp(1_000_000);
        adapter = new ChainlinkPriceAdapter(address(this));
        usdc = new MockERC20(6);
        weth = new MockERC20(18);
        dai = new MockERC20(18);
        usdcFeed = new MockAggregator(8);
        wethFeed = new MockAggregator(8);
        daiFeed = new MockAggregator(18);

        _fresh(usdcFeed, 1e8); // $1.00
        _fresh(wethFeed, 3000e8); // $3000.00
        _fresh(daiFeed, 1e18); // $1.00 at 18-dp feed

        adapter.setFeed(address(usdc), address(usdcFeed), STALE);
        adapter.setFeed(address(weth), address(wethFeed), STALE);
        adapter.setFeed(address(dai), address(daiFeed), STALE);
    }

    function _fresh(MockAggregator feed, int256 answer) internal {
        feed.set(1, answer, block.timestamp, 1);
    }

    // ----------------------------- decimals math --------------------------
    function test_price_usdFeed_18dp_basic() public view {
        assertEq(adapter.priceToUsd(address(weth), 2e18), 600_000_000_000); // 2 WETH @ $3000 = $6000.00
    }

    function test_price_decimals_token6dp() public view {
        assertEq(adapter.priceToUsd(address(usdc), 1500e6), 150_000_000_000); // 1500 USDC = $1500.00
    }

    function test_price_decimals_feedNot8() public view {
        // 18-dp feed must be honored via feed.decimals(), never assumed to be 8
        assertEq(adapter.priceToUsd(address(dai), 1000e18), 100_000_000_000); // 1000 DAI = $1000.00
    }

    // ------------------------------- freshness ----------------------------
    function test_price_boundary_freshAtExactStaleness() public {
        usdcFeed.set(1, 1e8, block.timestamp - STALE, 1); // exactly at the bound => fresh
        assertEq(adapter.priceToUsd(address(usdc), 1e6), 1e8);
    }

    function test_price_revert_staleRound() public {
        usdcFeed.set(1, 1e8, block.timestamp - STALE - 1, 1); // one second too old
        vm.expectRevert(ChainlinkPriceAdapter.StaleRound.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_answeredInRoundLtRoundId() public {
        usdcFeed.set(5, 1e8, block.timestamp, 4); // answeredInRound < roundId
        vm.expectRevert(ChainlinkPriceAdapter.StaleRound.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_nonPositiveAnswer() public {
        usdcFeed.set(1, 0, block.timestamp, 1);
        vm.expectRevert(ChainlinkPriceAdapter.NonPositiveAnswer.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_negativeAnswer() public {
        usdcFeed.set(1, -1, block.timestamp, 1);
        vm.expectRevert(ChainlinkPriceAdapter.NonPositiveAnswer.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_updatedAtZero() public {
        usdcFeed.set(1, 1e8, 0, 1);
        vm.expectRevert(ChainlinkPriceAdapter.IncompleteRound.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_futureUpdatedAt() public {
        usdcFeed.set(1, 1e8, block.timestamp + 1, 1);
        vm.expectRevert(ChainlinkPriceAdapter.FuturePrice.selector);
        adapter.priceToUsd(address(usdc), 1e6);
    }

    function test_price_revert_unregisteredToken() public {
        vm.expectRevert(abi.encodeWithSelector(ChainlinkPriceAdapter.FeedNotSet.selector, address(0x999)));
        adapter.priceToUsd(address(0x999), 1e6);
    }

    // -------------------------------- auth --------------------------------
    function test_setFeed_revert_notOwner() public {
        vm.expectRevert(ChainlinkPriceAdapter.NotOwner.selector);
        vm.prank(address(0xE0A));
        adapter.setFeed(address(usdc), address(usdcFeed), STALE);
    }

    function test_setFeed_revert_tokenWithoutDecimals() public {
        // a non-contract / token without decimals() fails at registration, not in the hot path
        vm.expectRevert();
        adapter.setFeed(address(0xDEAD), address(usdcFeed), STALE);
    }

    function test_removeFeed_thenPriceReverts() public {
        adapter.removeFeed(address(usdc));
        vm.expectRevert(abi.encodeWithSelector(ChainlinkPriceAdapter.FeedNotSet.selector, address(usdc)));
        adapter.priceToUsd(address(usdc), 1e6);
    }
}
