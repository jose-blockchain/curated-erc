// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC3525} from "../../src/token/ERC3525/ERC3525.sol";
import {IERC3525} from "../../src/token/ERC3525/IERC3525.sol";
import {IERC3525Receiver} from "../../src/token/ERC3525/IERC3525Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MockERC3525 is ERC3525 {
    constructor() ERC3525("SFT", "SFT", 18) {}

    function mint(address to, uint256 slot, uint256 value) external returns (uint256) {
        return _mint(to, slot, value);
    }
}

contract ERC3525Receiver is IERC3525Receiver {
    event Received(address operator, uint256 fromTokenId, uint256 toTokenId, uint256 value, bytes data);

    function onERC3525Received(
        address operator,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        emit Received(operator, fromTokenId, toTokenId, value, data);
        return IERC3525Receiver.onERC3525Received.selector;
    }
}

contract ERC3525RejectingReceiver is IERC165, IERC3525Receiver {
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC3525Receiver).interfaceId;
    }

    function onERC3525Received(address, uint256, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return 0xdeadbeef;
    }
}

contract ERC721ReceiverMock is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// Reentrancy attack: tries to call transferFrom during onERC3525Received
contract ERC3525ReentrantReceiver is IERC165, IERC3525Receiver {
    IERC3525 public target;
    uint256 public fromId;
    uint256 public toId;
    uint256 public attackValue;

    constructor(IERC3525 target_) {
        target = target_;
    }

    function setAttack(uint256 fromId_, uint256 toId_, uint256 value_) external {
        fromId = fromId_;
        toId = toId_;
        attackValue = value_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC3525Receiver).interfaceId || id == type(IERC165).interfaceId;
    }

    function onERC3525Received(address, uint256, uint256, uint256, bytes calldata) external override returns (bytes4) {
        if (fromId != 0 && toId != 0 && attackValue != 0) {
            target.transferFrom(fromId, toId, attackValue);
        }
        return IERC3525Receiver.onERC3525Received.selector;
    }
}

contract ERC3525Test is Test {
    MockERC3525 internal sft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 constant SLOT_A = 1;
    uint256 constant SLOT_B = 2;

    function setUp() public {
        sft = new MockERC3525();
    }

    // --- ERC165 ---

    function test_supportsInterface() public view {
        assertTrue(sft.supportsInterface(type(IERC3525).interfaceId));
    }

    // --- Mint ---

    function test_mint() public {
        uint256 id = sft.mint(alice, SLOT_A, 100e18);
        assertEq(id, 1);
        assertEq(sft.ownerOf(1), alice);
        assertEq(sft.slotOf(1), SLOT_A);
        assertEq(sft.balanceOf(1), 100e18);
        assertEq(sft.balanceOf(alice), 1);
    }

    function test_mint_multipleSlots() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(alice, SLOT_B, 50e18);
        assertEq(sft.balanceOf(alice), 2);
        assertEq(sft.slotOf(1), SLOT_A);
        assertEq(sft.slotOf(2), SLOT_B);
    }

    // --- Value transfer (token to token, same slot) ---

    function test_transferValue_tokenToToken() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.transferFrom(1, 2, 50e18);

        assertEq(sft.balanceOf(1), 50e18);
        assertEq(sft.balanceOf(2), 50e18);
    }

    function test_transferValue_tokenToToken_revert_slotMismatch() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_B, 0);

        vm.prank(alice);
        vm.expectRevert();
        sft.transferFrom(1, 2, 50e18);
    }

    function test_transferValue_tokenToToken_revert_insufficientBalance() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        vm.expectRevert();
        sft.transferFrom(1, 2, 200e18);
    }

    // --- Value transfer (token to address) ---

    function test_transferValue_tokenToAddress_createsNewToken() public {
        sft.mint(alice, SLOT_A, 100e18);

        vm.prank(alice);
        uint256 toId = sft.transferFrom(1, bob, 30e18);

        assertEq(toId, 2);
        assertEq(sft.ownerOf(2), bob);
        assertEq(sft.balanceOf(1), 70e18);
        assertEq(sft.balanceOf(2), 30e18);
    }

    function test_transferValue_tokenToAddress_reusesExistingSlot() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        uint256 toId = sft.transferFrom(1, bob, 30e18);

        assertEq(toId, 2);
        assertEq(sft.balanceOf(2), 30e18);
    }

    // --- ERC721 transfer ---

    function test_transferToken() public {
        sft.mint(alice, SLOT_A, 100e18);

        vm.prank(alice);
        sft.transferFrom(alice, bob, 1);

        assertEq(sft.ownerOf(1), bob);
        assertEq(sft.balanceOf(bob), 1);
    }

    // --- Value approval ---

    function test_approveValue() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.approve(1, bob, 50e18);

        vm.prank(bob);
        sft.transferFrom(1, 2, 50e18);

        assertEq(sft.balanceOf(1), 50e18);
        assertEq(sft.balanceOf(2), 50e18);
    }

    function test_approveValue_spendAllowance() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(carol, SLOT_A, 0);

        vm.prank(alice);
        sft.approve(1, carol, 40e18);

        vm.prank(carol);
        sft.transferFrom(1, 2, 40e18);

        assertEq(sft.allowance(1, carol), 0);
    }

    // --- IERC3525Receiver callback ---

    function test_transferValue_invokesReceiverCallback() public {
        ERC3525Receiver receiver = new ERC3525Receiver();
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(address(receiver), SLOT_A, 0);

        vm.prank(alice);
        sft.transferFrom(1, 2, 10e18);

        assertEq(sft.balanceOf(1), 90e18);
        assertEq(sft.balanceOf(2), 10e18);
    }

    // --- Enumerable ---

    function test_tokenByIndex() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_B, 50e18);
        assertEq(sft.tokenByIndex(0), 1);
        assertEq(sft.tokenByIndex(1), 2);
    }

    function test_tokenOfOwnerByIndex() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(alice, SLOT_B, 50e18);
        assertEq(sft.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(sft.tokenOfOwnerByIndex(alice, 1), 2);
    }

    function test_tokenByIndex_revert_outOfBounds() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.expectRevert();
        sft.tokenByIndex(1);
    }

    function test_tokenOfOwnerByIndex_revert_outOfBounds() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.expectRevert();
        sft.tokenOfOwnerByIndex(alice, 1);
    }

    // --- ERC721 approve / setApprovalForAll ---

    function test_transferByApproved() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        sft.approve(bob, 1);

        vm.prank(bob);
        sft.transferFrom(alice, bob, 1);
        assertEq(sft.ownerOf(1), bob);
    }

    function test_transferByOperator() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        sft.setApprovalForAll(carol, true);

        vm.prank(carol);
        sft.transferFrom(alice, bob, 1);
        assertEq(sft.ownerOf(1), bob);
    }

    function test_tokenTransfer_clearsValueAllowances() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);
        vm.prank(alice);
        sft.approve(1, carol, 50e18);
        assertEq(sft.allowance(1, carol), 50e18);

        vm.prank(alice);
        sft.transferFrom(alice, bob, 1);

        assertEq(sft.ownerOf(1), bob);
        assertEq(sft.allowance(1, carol), 0);
        vm.prank(carol);
        vm.expectRevert();
        sft.transferFrom(1, 2, 10e18);
    }

    function test_transfer_revert_unauthorized() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(bob);
        vm.expectRevert();
        sft.transferFrom(alice, bob, 1);
    }

    function test_approve_revert_toSelf() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        vm.expectRevert();
        sft.approve(alice, 1);
    }

    function test_setApprovalForAll_revert_toSelf() public {
        vm.prank(alice);
        vm.expectRevert();
        sft.setApprovalForAll(alice, true);
    }

    // --- safeTransferFrom ---

    function test_safeTransferFrom_toEOA() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        sft.safeTransferFrom(alice, bob, 1);
        assertEq(sft.ownerOf(1), bob);
    }

    function test_safeTransferFrom_toERC721Receiver() public {
        ERC721ReceiverMock receiver = new ERC721ReceiverMock();
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        sft.safeTransferFrom(alice, address(receiver), 1);
        assertEq(sft.ownerOf(1), address(receiver));
    }

    // --- Invalid / revert cases ---

    function test_balanceOf_revert_nonexistentToken() public {
        vm.expectRevert();
        sft.balanceOf(999);
    }

    function test_ownerOf_revert_nonexistentToken() public {
        vm.expectRevert();
        sft.ownerOf(999);
    }

    function test_slotOf_revert_nonexistentToken() public {
        vm.expectRevert();
        sft.slotOf(999);
    }

    function test_balanceOf_revert_zeroAddress() public {
        vm.expectRevert();
        sft.balanceOf(address(0));
    }

    function test_transfer_revert_toZeroAddress() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(alice);
        vm.expectRevert();
        sft.transferFrom(alice, address(0), 1);
    }

    function test_transferValue_revert_insufficientAllowance() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);
        vm.prank(alice);
        sft.approve(1, carol, 10e18);

        vm.prank(carol);
        vm.expectRevert();
        sft.transferFrom(1, 2, 50e18);
    }

    function test_approveValue_revert_unauthorized() public {
        sft.mint(alice, SLOT_A, 100e18);
        vm.prank(bob);
        vm.expectRevert();
        sft.approve(1, carol, 50e18);
    }

    // --- Value approval: type(uint256).max (infinite) ---

    function test_approveValue_maxUint_allowsMultipleTransfers() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.approve(1, bob, type(uint256).max);

        vm.prank(bob);
        sft.transferFrom(1, 2, 30e18);
        vm.prank(bob);
        sft.transferFrom(1, 2, 30e18);
        assertEq(sft.allowance(1, bob), type(uint256).max);
        assertEq(sft.balanceOf(1), 40e18);
    }

    // --- Zero value transfer (token to token) ---

    function test_transferValue_zeroValue() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 50e18);

        vm.prank(alice);
        sft.transferFrom(1, 2, 0);

        assertEq(sft.balanceOf(1), 100e18);
        assertEq(sft.balanceOf(2), 50e18);
    }

    // --- Full value transfer (drain token) ---

    function test_transferValue_fullBalance() public {
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.transferFrom(1, 2, 100e18);

        assertEq(sft.balanceOf(1), 0);
        assertEq(sft.balanceOf(2), 100e18);
    }

    // --- ERC3525Receiver rejection ---

    function test_transferValue_revert_receiverRejects() public {
        ERC3525RejectingReceiver receiver = new ERC3525RejectingReceiver();
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(address(receiver), SLOT_A, 0);

        vm.prank(alice);
        vm.expectRevert();
        sft.transferFrom(1, 2, 10e18);
    }

    // --- Reentrancy: receiver cannot re-enter ---

    function test_reentrancy_receiverBlocked() public {
        ERC3525ReentrantReceiver receiver = new ERC3525ReentrantReceiver(IERC3525(address(sft)));
        sft.mint(alice, SLOT_A, 100e18);
        sft.mint(address(receiver), SLOT_A, 0);
        sft.mint(address(receiver), SLOT_A, 0);
        receiver.setAttack(2, 3, 5e18);

        vm.prank(alice);
        vm.expectRevert();
        sft.transferFrom(1, 2, 10e18);
    }

    // --- Metadata ---

    function test_metadata() public view {
        assertEq(sft.name(), "SFT");
        assertEq(sft.symbol(), "SFT");
        assertEq(sft.valueDecimals(), 18);
    }

    function test_tokenURI() public {
        sft.mint(alice, SLOT_A, 100e18);
        assertEq(sft.tokenURI(1), "1");
    }

    function test_totalSupply() public {
        assertEq(sft.totalSupply(), 0);
        sft.mint(alice, SLOT_A, 100e18);
        assertEq(sft.totalSupply(), 1);
        sft.mint(bob, SLOT_B, 50e18);
        assertEq(sft.totalSupply(), 2);
    }

    // --- getApproved ---

    function test_getApproved() public {
        sft.mint(alice, SLOT_A, 100e18);
        assertEq(sft.getApproved(1), address(0));
        vm.prank(alice);
        sft.approve(bob, 1);
        assertEq(sft.getApproved(1), bob);
    }

    function test_getApproved_revert_nonexistent() public {
        vm.expectRevert();
        sft.getApproved(999);
    }

    // --- Fuzz ---

    function testFuzz_mintAndTransfer(address to, uint256 slot, uint256 value) public {
        vm.assume(to != address(0));
        vm.assume(slot != 0);
        vm.assume(value <= type(uint128).max);

        uint256 id = sft.mint(to, slot, value);
        assertEq(sft.ownerOf(id), to);
        assertEq(sft.slotOf(id), slot);
        assertEq(sft.balanceOf(id), value);
    }

    function testFuzz_transferValue_conservesTotal(uint256 value1, uint256 value2, uint256 transferAmt) public {
        value1 = bound(value1, 1, type(uint128).max);
        value2 = bound(value2, 0, type(uint128).max);
        transferAmt = bound(transferAmt, 0, value1);

        sft.mint(alice, SLOT_A, value1);
        sft.mint(bob, SLOT_A, value2);

        uint256 totalBefore = value1 + value2;
        vm.prank(alice);
        sft.transferFrom(1, 2, transferAmt);
        uint256 totalAfter = sft.balanceOf(1) + sft.balanceOf(2);
        assertEq(totalBefore, totalAfter);
    }

    function testFuzz_approveThenTransferByOperator(uint256 value, uint256 transferAmt) public {
        value = bound(value, 1, type(uint128).max);
        transferAmt = bound(transferAmt, 1, value);

        sft.mint(alice, SLOT_A, value);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.approve(1, carol, transferAmt);
        vm.prank(carol);
        sft.transferFrom(1, 2, transferAmt);

        assertEq(sft.balanceOf(1), value - transferAmt);
        assertEq(sft.balanceOf(2), transferAmt);
    }

    function testFuzz_setApprovalForAll_allowsValueTransfer(uint256 value) public {
        value = bound(value, 1, type(uint128).max);
        sft.mint(alice, SLOT_A, value);
        sft.mint(bob, SLOT_A, 0);

        vm.prank(alice);
        sft.setApprovalForAll(carol, true);
        vm.prank(carol);
        sft.transferFrom(1, 2, value);
        assertEq(sft.balanceOf(1), 0);
        assertEq(sft.balanceOf(2), value);
    }
}
