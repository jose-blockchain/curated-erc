// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC4907} from "../../src/token/ERC4907/ERC4907.sol";
import {IERC4907} from "../../src/token/ERC4907/IERC4907.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC4907 is ERC4907 {
    constructor() ERC721("Rental", "RENT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract ERC4907Test is Test {
    MockERC4907 internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        nft = new MockERC4907();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        vm.warp(1000);
    }

    // --- ERC165 ---

    function test_supportsInterface() public view {
        assertTrue(nft.supportsInterface(type(IERC4907).interfaceId));
    }

    // --- setUser ---

    function test_setUser_byOwner() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC4907.UpdateUser(1, bob, 2000);
        nft.setUser(1, bob, 2000);

        assertEq(nft.userOf(1), bob);
        assertEq(nft.userExpires(1), 2000);
    }

    function test_setUser_byApproved() public {
        vm.prank(alice);
        nft.approve(carol, 1);

        vm.prank(carol);
        nft.setUser(1, bob, 2000);
        assertEq(nft.userOf(1), bob);
    }

    function test_setUser_byOperator() public {
        vm.prank(alice);
        nft.setApprovalForAll(carol, true);

        vm.prank(carol);
        nft.setUser(1, bob, 3000);
        assertEq(nft.userOf(1), bob);
    }

    function test_setUser_revert_unauthorized() public {
        vm.prank(bob);
        vm.expectRevert();
        nft.setUser(1, bob, 2000);
    }

    // --- userOf ---

    function test_userOf_returnsZero_whenNotSet() public view {
        assertEq(nft.userOf(1), address(0));
    }

    function test_userOf_returnsZero_whenExpired() public {
        vm.prank(alice);
        nft.setUser(1, bob, 500);
        assertEq(nft.userOf(1), address(0));
    }

    function test_userOf_returnsUser_whenNotExpired() public {
        vm.prank(alice);
        nft.setUser(1, bob, 2000);
        assertEq(nft.userOf(1), bob);
    }

    function test_userOf_returnsUser_atExactExpiry() public {
        vm.prank(alice);
        nft.setUser(1, bob, 1000);
        assertEq(nft.userOf(1), bob);
    }

    // --- transfer clears user ---

    function test_transfer_clearsUser() public {
        vm.prank(alice);
        nft.setUser(1, bob, 5000);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IERC4907.UpdateUser(1, address(0), 0);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.userOf(1), address(0));
        assertEq(nft.userExpires(1), 0);
    }

    // --- Fuzz ---

    function testFuzz_setUser(address user, uint64 expires) public {
        vm.assume(user != address(0));
        vm.prank(alice);
        nft.setUser(1, user, expires);

        if (expires >= block.timestamp) {
            assertEq(nft.userOf(1), user);
        } else {
            assertEq(nft.userOf(1), address(0));
        }
        assertEq(nft.userExpires(1), expires);
    }

    function testFuzz_transferClearsUser(uint64 expires) public {
        vm.assume(expires >= block.timestamp);
        vm.prank(alice);
        nft.setUser(1, bob, expires);
        assertEq(nft.userOf(1), bob);

        vm.prank(alice);
        nft.transferFrom(alice, carol, 1);
        assertEq(nft.userOf(1), address(0));
    }

    // --- Set user to address(0) ---

    function test_setUser_toZeroAddress() public {
        vm.prank(alice);
        nft.setUser(1, bob, 2000);
        assertEq(nft.userOf(1), bob);

        vm.prank(alice);
        nft.setUser(1, address(0), 2000);
        assertEq(nft.userOf(1), address(0));
    }

    // --- Override user ---

    function test_setUser_overridesExisting() public {
        vm.prank(alice);
        nft.setUser(1, bob, 2000);
        assertEq(nft.userOf(1), bob);

        vm.prank(alice);
        nft.setUser(1, carol, 3000);
        assertEq(nft.userOf(1), carol);
        assertEq(nft.userExpires(1), 3000);
    }

    // --- User expires after warp ---

    function test_userOf_expiresAfterTimeAdvance() public {
        vm.prank(alice);
        nft.setUser(1, bob, 1500);
        assertEq(nft.userOf(1), bob);

        vm.warp(1501);
        assertEq(nft.userOf(1), address(0));
    }

    // --- userExpires returns raw value even when expired ---

    function test_userExpires_returnsRawEvenWhenExpired() public {
        vm.prank(alice);
        nft.setUser(1, bob, 500);
        assertEq(nft.userOf(1), address(0));
        assertEq(nft.userExpires(1), 500);
    }

    // --- safeTransferFrom clears user ---

    function test_safeTransferFrom_clearsUser() public {
        vm.prank(alice);
        nft.setUser(1, bob, 5000);

        vm.prank(alice);
        nft.safeTransferFrom(alice, carol, 1);
        assertEq(nft.userOf(1), address(0));
        assertEq(nft.userExpires(1), 0);
    }

    // --- Nonexistent token has no user ---

    function test_userOf_nonexistentToken() public view {
        assertEq(nft.userOf(999), address(0));
        assertEq(nft.userExpires(999), 0);
    }

    // --- setUser on nonexistent token reverts ---

    function test_setUser_revert_nonexistentToken() public {
        vm.expectRevert();
        nft.setUser(999, bob, 2000);
    }

    // --- Fuzz: setUser then transfer, user always cleared ---

    function testFuzz_setUserThenTransfer(address user, uint64 expires) public {
        vm.assume(user != address(0));
        vm.assume(expires >= block.timestamp);
        vm.prank(alice);
        nft.setUser(1, user, expires);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.userOf(1), address(0));
        assertEq(nft.userExpires(1), 0);
    }
}
