// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC721Consecutive} from "../../src/token/ERC2309/ERC721Consecutive.sol";
import {IERC2309} from "../../src/token/ERC2309/IERC2309.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockConsecutive is ERC721Consecutive {
    constructor(address batchRecipient, uint96 batchSize) ERC721("Consecutive", "CONS") {
        _mintConsecutive(batchRecipient, batchSize);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _update(address(0), tokenId, _ownerOf(tokenId));
    }
}

contract MultiBatchConsecutive is ERC721Consecutive {
    constructor(address recipient1, uint96 size1, address recipient2, uint96 size2) ERC721("MultiBatch", "MB") {
        _mintConsecutive(recipient1, size1);
        _mintConsecutive(recipient2, size2);
    }
}

contract ERC2309Test is Test {
    MockConsecutive internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    uint96 internal constant BATCH = 100;

    function setUp() public {
        nft = new MockConsecutive(alice, BATCH);
    }

    // --- Consecutive mint ---

    function test_consecutiveMint_ownership() public view {
        for (uint256 i = 0; i < 10; i++) {
            assertEq(nft.ownerOf(i), alice);
        }
        assertEq(nft.ownerOf(99), alice);
    }

    function test_consecutiveMint_totalMinted() public view {
        assertEq(nft.totalConsecutiveMinted(), BATCH);
    }

    function test_consecutiveMint_balanceOf() public view {
        assertEq(nft.balanceOf(alice), BATCH);
    }

    function test_consecutiveMint_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC2309.ConsecutiveTransfer(0, 49, address(0), bob);
        new MockConsecutive(bob, 50);
    }

    // --- Transfer of consecutive tokens ---

    function test_transfer_consecutiveToken() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 5);
        assertEq(nft.ownerOf(5), bob);
        assertEq(nft.ownerOf(4), alice);
        assertEq(nft.ownerOf(6), alice);
    }

    function test_transfer_updatesBalances() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 5);
        assertEq(nft.balanceOf(alice), BATCH - 1);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_transfer_consecutiveToken_secondTransfer() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 5);

        vm.prank(bob);
        nft.transferFrom(bob, carol, 5);
        assertEq(nft.ownerOf(5), carol);
    }

    function test_transfer_revert_unauthorized() public {
        vm.prank(bob);
        vm.expectRevert();
        nft.transferFrom(alice, bob, 10);
    }

    // --- Burn ---

    function test_burn_consecutiveToken() public {
        nft.burn(0);
        vm.expectRevert();
        nft.ownerOf(0);
        assertEq(nft.balanceOf(alice), BATCH - 1);
    }

    function test_burn_thenOwnerOfReverts() public {
        nft.burn(50);
        vm.expectRevert();
        nft.ownerOf(50);
    }

    // --- Multi-batch ---

    function test_multiBatch() public {
        MultiBatchConsecutive multi = new MultiBatchConsecutive(alice, 50, bob, 30);

        for (uint256 i = 0; i < 50; i++) {
            assertEq(multi.ownerOf(i), alice);
        }
        for (uint256 i = 50; i < 80; i++) {
            assertEq(multi.ownerOf(i), bob);
        }
        assertEq(multi.totalConsecutiveMinted(), 80);
        assertEq(multi.balanceOf(alice), 50);
        assertEq(multi.balanceOf(bob), 30);
    }

    // --- Post-construction mint ---

    function test_postConstructionMint() public {
        nft.mint(bob, 200);
        assertEq(nft.ownerOf(200), bob);
        assertEq(nft.balanceOf(bob), 1);
    }

    // --- Fuzz ---

    function testFuzz_ownershipConsecutive(uint256 tokenId) public view {
        tokenId = bound(tokenId, 0, BATCH - 1);
        assertEq(nft.ownerOf(tokenId), alice);
    }

    function testFuzz_transferConsecutive(uint256 tokenId) public {
        tokenId = bound(tokenId, 0, BATCH - 1);
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(alice), BATCH - 1);
        assertEq(nft.balanceOf(bob), 1);
    }

    // --- Burn non-consecutive token ---

    function test_burn_nonConsecutiveToken() public {
        nft.mint(bob, 200);
        assertEq(nft.balanceOf(bob), 1);
        nft.burn(200);
        vm.expectRevert();
        nft.ownerOf(200);
        assertEq(nft.balanceOf(bob), 0);
    }

    // --- Multiple burns ---

    function test_multipleBurns_consecutiveTokens() public {
        nft.burn(0);
        nft.burn(1);
        nft.burn(99);

        vm.expectRevert();
        nft.ownerOf(0);
        vm.expectRevert();
        nft.ownerOf(1);
        vm.expectRevert();
        nft.ownerOf(99);

        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.ownerOf(50), alice);
        assertEq(nft.balanceOf(alice), BATCH - 3);
    }

    // --- ownerOf out of range returns zero/reverts ---

    function test_ownerOf_outOfRange_reverts() public {
        vm.expectRevert();
        nft.ownerOf(BATCH);
        vm.expectRevert();
        nft.ownerOf(BATCH + 1);
        vm.expectRevert();
        nft.ownerOf(type(uint256).max);
    }

    // --- Transfer then burn ---

    function test_transferThenBurn() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 10);
        assertEq(nft.ownerOf(10), bob);

        nft.burn(10);
        vm.expectRevert();
        nft.ownerOf(10);
        assertEq(nft.balanceOf(bob), 0);
        assertEq(nft.balanceOf(alice), BATCH - 1);
    }

    // --- Zero-size batch (no-op) ---

    function test_zeroBatchSize() public {
        MockConsecutive zeroNft = new MockConsecutive(alice, 0);
        assertEq(zeroNft.totalConsecutiveMinted(), 0);
        assertEq(zeroNft.balanceOf(alice), 0);
    }

    // --- Max batch size exceeded ---

    function test_maxBatchSize_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC721Consecutive.ERC721ConsecutiveExceededMaxBatch.selector, 5001, 5000)
        );
        new MockConsecutive(alice, 5001);
    }

    // --- Fuzz burn consecutive ---

    function testFuzz_burnConsecutive(uint256 tokenId) public {
        tokenId = bound(tokenId, 0, BATCH - 1);
        nft.burn(tokenId);
        vm.expectRevert();
        nft.ownerOf(tokenId);
        assertEq(nft.balanceOf(alice), BATCH - 1);
    }
}
