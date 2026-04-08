// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7818} from "../../src/token/ERC7818/ERC7818.sol";
import {IERC7818} from "../../src/token/ERC7818/IERC7818.sol";

// -----------------------------------------------------------------------------
// Mock token
// -----------------------------------------------------------------------------

contract MockToken is ERC7818 {
    constructor(uint256 epochDuration_, uint256 validityPeriod_, IERC7818.EPOCH_TYPE epochType_)
        ERC7818("Mock", "MCK", epochDuration_, validityPeriod_, epochType_)
    {}

    function mint(address to, uint256 amount) external {
        _mintExpirable(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burnExpirable(from, amount);
    }

    function epochValid_exposed(uint256 target, uint256 current) external view returns (bool) {
        return _epochValid(target, current);
    }
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

contract ERC7818Test is Test {
    uint256 constant EPOCH  = 7 days;
    uint256 constant VALID  = 2;
    uint256 constant AMOUNT = 1000e18;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    MockToken token;

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockToken(EPOCH, VALID, IERC7818.EPOCH_TYPE.TIME_BASED);
    }

    // =========================================================================
    // 1. Metadata
    // =========================================================================

    function test_metadata() public view {
        assertEq(token.name(),           "Mock");
        assertEq(token.symbol(),         "MCK");
        assertEq(token.decimals(),       18);
        assertEq(token.epochDuration(),  EPOCH);
        assertEq(token.validityPeriod(), VALID);
        assertEq(uint8(token.epochType()), uint8(IERC7818.EPOCH_TYPE.TIME_BASED));
    }

    function test_initialEpochZero() public view {
        assertEq(token.currentEpoch(), 0);
    }

    // =========================================================================
    // 2. Minting
    // =========================================================================

    function test_mint_balanceAndSupply() public {
        token.mint(alice, AMOUNT);
        assertEq(token.balanceOf(alice), AMOUNT);
        assertEq(token.totalSupply(),    AMOUNT);
    }

    function test_mint_emitsMintedInEpoch() public {
        vm.expectEmit(true, true, false, true);
        emit IERC7818.MintedInEpoch(alice, 0, AMOUNT);
        token.mint(alice, AMOUNT);
    }

    function test_mint_emitsTransfer() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), alice, AMOUNT);
        token.mint(alice, AMOUNT);
    }

    function test_mint_multipleEpochs() public {
        token.mint(alice, 600e18);
        vm.warp(block.timestamp + EPOCH);
        token.mint(alice, 400e18);

        assertEq(token.balanceOf(alice),           1000e18);
        assertEq(token.balanceOfAtEpoch(0, alice),  600e18);
        assertEq(token.balanceOfAtEpoch(1, alice),  400e18);
    }

    function test_mint_zeroNoEffect() public {
        token.mint(alice, 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(),    0);
    }

    // =========================================================================
    // 3. balanceOf excludes expired tokens
    // =========================================================================

    function test_balanceOf_zeroAfterExpiry() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        assertEq(token.currentEpoch(),   2);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_balanceOf_partialExpiry() public {
        token.mint(alice, 600e18);
        vm.warp(block.timestamp + EPOCH);
        token.mint(alice, 400e18);
        vm.warp(block.timestamp + EPOCH); // epoch 2: epoch 0 expired

        assertEq(token.balanceOf(alice), 400e18);
    }

    function test_balanceOfAtEpoch_zeroWhenExpired() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        assertEq(token.balanceOfAtEpoch(0, alice), 0);
    }

    function test_getEpochBalance_rawEvenExpired() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        assertEq(token.getEpochBalance(0, alice), AMOUNT);
    }

    // =========================================================================
    // 4. Transfer — valid tokens
    // =========================================================================

    function test_transfer_basic() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.transfer(bob, 300e18);
        assertEq(token.balanceOf(alice), 700e18);
        assertEq(token.balanceOf(bob),   300e18);
    }

    function test_transfer_emitsEvent() public {
        token.mint(alice, AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(alice, bob, 300e18);
        vm.prank(alice);
        token.transfer(bob, 300e18);
    }

    function test_transfer_recipientInheritsEpoch() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.transfer(bob, 300e18);
        assertEq(token.balanceOfAtEpoch(0, bob), 300e18);
    }

    function test_transfer_fifo_oldestFirst() public {
        token.mint(alice, 300e18);
        vm.warp(block.timestamp + EPOCH);
        token.mint(alice, 500e18);

        vm.prank(alice);
        token.transfer(bob, 350e18);

        assertEq(token.balanceOfAtEpoch(0, alice),   0,      "epoch 0 fully consumed");
        assertEq(token.balanceOfAtEpoch(1, alice), 450e18,   "epoch 1 partially consumed");
    }

    function test_transfer_fullBalance() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.transfer(bob, AMOUNT);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob),   AMOUNT);
    }

    function test_transfer_zeroSucceeds() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        bool ok = token.transfer(bob, 0);
        assertTrue(ok);
    }

    // =========================================================================
    // 5. Self-transfer — no double count bug
    // =========================================================================

    function test_transferToSelf_balanceUnchanged() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.transfer(alice, AMOUNT);
        // Must still be AMOUNT — not doubled
        assertEq(token.balanceOf(alice), AMOUNT);
    }

    function test_transferToSelf_emitsEvent() public {
        token.mint(alice, AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(alice, alice, AMOUNT);
        vm.prank(alice);
        token.transfer(alice, AMOUNT);
    }

    function test_transferToSelf_revertsIfExpired() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818TransferredExpiredToken.selector,
                alice,
                uint256(0)
            )
        );
        token.transfer(alice, 1);
    }

    function test_transferToSelf_revertsIfInsufficientActive() public {
        token.mint(alice, 50e18);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818InsufficientActiveBalance.selector,
                alice,
                uint256(50e18),
                uint256(100e18)
            )
        );
        token.transfer(alice, 100e18);
    }

    // =========================================================================
    // 6. Transfer — reverts on expired / insufficient
    // =========================================================================

    function test_transfer_revertsExpiredToken() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818TransferredExpiredToken.selector,
                alice,
                uint256(0)
            )
        );
        token.transfer(bob, 1);
    }

    function test_transfer_revertsInsufficientActive() public {
        token.mint(alice, 50e18);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818InsufficientActiveBalance.selector,
                alice,
                uint256(50e18),
                uint256(100e18)
            )
        );
        token.transfer(bob, 100e18);
    }

    // =========================================================================
    // 7. transferFrom + allowance
    // =========================================================================

    function test_transferFrom_basic() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.approve(bob, 200e18);

        vm.prank(bob);
        token.transferFrom(alice, bob, 200e18);

        assertEq(token.balanceOf(alice), 800e18);
        assertEq(token.balanceOf(bob),   200e18);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_transferFrom_infiniteAllowanceNotDecremented() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, bob, 200e18);

        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    function test_transferFrom_revertsInsufficientAllowance() public {
        token.mint(alice, AMOUNT);
        vm.prank(alice);
        token.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC7818.ERC7818InsufficientAllowance.selector,
                bob,
                uint256(100e18),
                uint256(200e18)
            )
        );
        token.transferFrom(alice, bob, 200e18);
    }

    // =========================================================================
    // 8. Batch expiry
    // =========================================================================

    function test_batchExpiry_multipleAccounts() public {
        token.mint(alice, 1000e18);
        token.mint(bob,    500e18);
        vm.warp(block.timestamp + EPOCH * VALID);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob),   0);
    }

    function test_batchExpiry_laterEpochUnaffected() public {
        token.mint(alice, 1000e18);
        vm.warp(block.timestamp + EPOCH);
        token.mint(bob, 500e18);
        vm.warp(block.timestamp + EPOCH); // epoch 2

        assertEq(token.balanceOf(alice), 0,       "epoch 0 expired");
        assertEq(token.balanceOf(bob),   500e18,  "epoch 1 still valid");
    }

    // =========================================================================
    // 9. Burn
    // =========================================================================

    function test_burn_reducesBalanceAndSupply() public {
        token.mint(alice, AMOUNT);
        token.burn(alice, 400e18);
        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.totalSupply(),    600e18);
    }

    function test_burn_revertsExpired() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818TransferredExpiredToken.selector,
                alice,
                uint256(0)
            )
        );
        token.burn(alice, 1);
    }

    function test_burn_revertsInsufficientActive() public {
        token.mint(alice, 50e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC7818.ERC7818InsufficientActiveBalance.selector,
                alice,
                uint256(50e18),
                uint256(100e18)
            )
        );
        token.burn(alice, 100e18);
    }

    // =========================================================================
    // 10. Epoch helpers
    // =========================================================================

    function test_getEpochInfo_contiguous() public view {
        (uint256 s0, uint256 e0) = token.getEpochInfo(0);
        (uint256 s1, uint256 e1) = token.getEpochInfo(1);
        assertEq(e0 - s0, EPOCH);
        assertEq(s1, e0);
        assertEq(e1 - s1, EPOCH);
    }

    function test_getNearestExpiryOf_empty() public view {
        (uint256 amount, uint256 expiry) = token.getNearestExpiryOf(alice);
        assertEq(amount, 0);
        assertEq(expiry, 0);
    }

    function test_getNearestExpiryOf_returnsOldest() public {
        token.mint(alice, 300e18);
        vm.warp(block.timestamp + EPOCH);
        token.mint(alice, 200e18);

        (uint256 amount, uint256 expiry) = token.getNearestExpiryOf(alice);
        assertEq(amount, 300e18);

        (uint256 s0,) = token.getEpochInfo(0);
        assertEq(expiry, s0 + VALID * EPOCH);
    }

    // =========================================================================
    // 11. totalSupply
    // =========================================================================

    function test_totalSupply_includesExpired() public {
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + EPOCH * VALID);
        assertEq(token.totalSupply(), AMOUNT); // does not decrease on expiry
    }

    function test_totalSupply_decreasesOnBurn() public {
        token.mint(alice, AMOUNT);
        token.burn(alice, 400e18);
        assertEq(token.totalSupply(), 600e18);
    }

    // =========================================================================
    // 12. Blocks-based variant
    // =========================================================================

    function test_blocksBased_epochAdvances() public {
        MockToken bt = new MockToken(100, 2, IERC7818.EPOCH_TYPE.BLOCKS_BASED);
        assertEq(bt.currentEpoch(), 0);
        vm.roll(block.number + 100);
        assertEq(bt.currentEpoch(), 1);
    }

    function test_blocksBased_expiry() public {
        MockToken bt = new MockToken(100, 2, IERC7818.EPOCH_TYPE.BLOCKS_BASED);
        bt.mint(alice, AMOUNT);
        vm.roll(block.number + 200);
        assertEq(bt.balanceOf(alice), 0);
    }

    // =========================================================================
    // 13. _epochValid boundary
    // =========================================================================

    function test_epochValid_boundary() public view {
        assertTrue(token.epochValid_exposed(0, 0));
        assertTrue(token.epochValid_exposed(0, 1));
        assertFalse(token.epochValid_exposed(0, 2));
    }

    function test_epochValid_futureIsFalse() public view {
        assertFalse(token.epochValid_exposed(5, 0));
    }

    // =========================================================================
    // 14. Fuzz
    // =========================================================================

    function testFuzz_mint_balanceEqualsAmount(uint96 amount) public {
        vm.assume(amount > 0);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzz_transfer_conservesBalance(uint96 mint_, uint96 send_) public {
        vm.assume(mint_ > 0 && send_ > 0 && send_ <= mint_);
        token.mint(alice, mint_);
        vm.prank(alice);
        token.transfer(bob, send_);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), mint_);
    }

    function testFuzz_expiredBalanceZero(uint8 warpEpochs) public {
        vm.assume(warpEpochs >= VALID);
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + uint256(warpEpochs) * EPOCH);
        assertEq(token.balanceOf(alice), 0);
    }

    function testFuzz_validBalanceBeforeExpiry(uint8 warpEpochs) public {
        vm.assume(warpEpochs < VALID);
        token.mint(alice, AMOUNT);
        vm.warp(block.timestamp + uint256(warpEpochs) * EPOCH);
        assertEq(token.balanceOf(alice), AMOUNT);
    }

    function testFuzz_selfTransferNoDoubleCount(uint96 amount) public {
        vm.assume(amount > 0);
        token.mint(alice, amount);
        vm.prank(alice);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }
}
