// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC5192} from "../../src/token/ERC5192/ERC5192.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC5192} from "../../src/token/ERC5192/IERC5192.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockERC5192 is ERC5192 {
    constructor() ERC721("Soulbound", "SBT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function lock(uint256 tokenId) external {
        _lock(tokenId);
    }

    function unlock(uint256 tokenId) external {
        _unlock(tokenId);
    }
}

contract ERC5192Test is Test {
    MockERC5192 internal sbt;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        sbt = new MockERC5192();
        sbt.mint(alice, 1);
        sbt.mint(alice, 2);
        sbt.mint(alice, 3);
    }

    // --- ERC165 ---

    function test_supportsInterface() public view {
        assertTrue(sbt.supportsInterface(type(IERC5192).interfaceId));
        assertTrue(sbt.supportsInterface(type(IERC165).interfaceId));
    }

    // --- locked ---

    function test_locked_defaultFalse() public view {
        assertFalse(sbt.locked(1));
    }

    function test_locked_afterLock() public {
        sbt.lock(1);
        assertTrue(sbt.locked(1));
    }

    function test_locked_afterUnlock() public {
        sbt.lock(1);
        sbt.unlock(1);
        assertFalse(sbt.locked(1));
    }

    function test_locked_revert_nonexistentToken() public {
        vm.expectRevert();
        sbt.locked(999);
    }

    // --- lock ---

    function test_lock_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC5192.Locked(1);
        sbt.lock(1);
    }

    function test_lock_revert_alreadyLocked() public {
        sbt.lock(1);
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenLocked.selector, 1));
        sbt.lock(1);
    }

    function test_lock_revert_nonexistentToken() public {
        vm.expectRevert();
        sbt.lock(999);
    }

    // --- unlock ---

    function test_unlock_emitsEvent() public {
        sbt.lock(2);
        vm.expectEmit(true, true, true, true);
        emit IERC5192.Unlocked(2);
        sbt.unlock(2);
    }

    function test_unlock_revert_notLocked() public {
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenNotLocked.selector, 1));
        sbt.unlock(1);
    }

    // --- transfer restriction ---

    function test_transfer_revert_whenLocked() public {
        sbt.lock(1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenLocked.selector, 1));
        sbt.transferFrom(alice, bob, 1);
    }

    function test_safeTransferFrom_revert_whenLocked() public {
        sbt.lock(1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenLocked.selector, 1));
        sbt.safeTransferFrom(alice, bob, 1);
    }

    function test_transfer_succeeds_whenUnlocked() public {
        vm.prank(alice);
        sbt.transferFrom(alice, bob, 1);
        assertEq(sbt.ownerOf(1), bob);
    }

    function test_transfer_succeeds_afterUnlock() public {
        sbt.lock(1);
        sbt.unlock(1);
        vm.prank(alice);
        sbt.transferFrom(alice, bob, 1);
        assertEq(sbt.ownerOf(1), bob);
    }

    // --- mint/burn always allowed ---

    function test_mint_succeeds_regardless() public {
        sbt.mint(bob, 100);
        assertEq(sbt.ownerOf(100), bob);
    }

    function test_burn_succeeds_whenLocked() public {
        sbt.lock(3);
        assertTrue(sbt.locked(3));
        sbt.burn(3);
        vm.expectRevert();
        sbt.ownerOf(3);
    }

    function test_burn_clearsLockState() public {
        sbt.lock(3);
        assertTrue(sbt.locked(3));
        sbt.burn(3);

        sbt.mint(bob, 3);
        assertFalse(sbt.locked(3));
    }

    // --- Fuzz ---

    function testFuzz_lockUnlockCycle(uint256 tokenId) public {
        tokenId = bound(tokenId, 10, 10_000);
        sbt.mint(alice, tokenId);

        assertFalse(sbt.locked(tokenId));

        sbt.lock(tokenId);
        assertTrue(sbt.locked(tokenId));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenLocked.selector, tokenId));
        sbt.transferFrom(alice, bob, tokenId);

        sbt.unlock(tokenId);
        assertFalse(sbt.locked(tokenId));

        vm.prank(alice);
        sbt.transferFrom(alice, bob, tokenId);
        assertEq(sbt.ownerOf(tokenId), bob);
    }

    // --- Approve still works on locked token ---

    function test_approve_succeeds_whenLocked() public {
        sbt.lock(1);
        vm.prank(alice);
        sbt.approve(bob, 1);
        assertEq(sbt.getApproved(1), bob);
    }

    function test_setApprovalForAll_succeeds_whenLocked() public {
        sbt.lock(1);
        vm.prank(alice);
        sbt.setApprovalForAll(bob, true);
        assertTrue(sbt.isApprovedForAll(alice, bob));
    }

    // --- Approved operator cannot transfer locked token ---

    function test_approvedOperator_cannotTransfer_whenLocked() public {
        vm.prank(alice);
        sbt.approve(bob, 1);
        sbt.lock(1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC5192.ERC5192TokenLocked.selector, 1));
        sbt.transferFrom(alice, bob, 1);
    }

    // --- Lock -> burn -> re-mint -> lock state is clean ---

    function test_burn_remint_lockStateClean() public {
        sbt.lock(1);
        sbt.burn(1);
        sbt.mint(bob, 1);
        assertFalse(sbt.locked(1));

        vm.prank(bob);
        sbt.transferFrom(bob, alice, 1);
        assertEq(sbt.ownerOf(1), alice);
    }

    // --- Fuzz burn locked token ---

    function testFuzz_burnLockedToken(uint256 tokenId) public {
        tokenId = bound(tokenId, 10, 10_000);
        sbt.mint(alice, tokenId);
        sbt.lock(tokenId);
        assertTrue(sbt.locked(tokenId));

        sbt.burn(tokenId);
        vm.expectRevert();
        sbt.ownerOf(tokenId);
    }
}
