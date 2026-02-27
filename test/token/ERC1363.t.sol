// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1363} from "../../src/token/ERC1363/ERC1363.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC1363Receiver} from "../../src/token/ERC1363/IERC1363Receiver.sol";
import {IERC1363Spender} from "../../src/token/ERC1363/IERC1363Spender.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// --- Test helpers ---

contract MockERC1363 is ERC1363 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ValidReceiver is IERC1363Receiver {
    event Received(address operator, address from, uint256 value, bytes data);

    function onTransferReceived(address operator, address from, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        emit Received(operator, from, value, data);
        return IERC1363Receiver.onTransferReceived.selector;
    }
}

contract RejectingReceiver is IERC1363Receiver {
    function onTransferReceived(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return bytes4(0xdeadbeef);
    }
}

contract RevertingReceiver is IERC1363Receiver {
    error CustomRevert();

    function onTransferReceived(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        revert CustomRevert();
    }
}

contract ValidSpender is IERC1363Spender {
    event Approved(address owner, uint256 value, bytes data);

    function onApprovalReceived(address owner, uint256 value, bytes calldata data) external override returns (bytes4) {
        emit Approved(owner, value, data);
        return IERC1363Spender.onApprovalReceived.selector;
    }
}

contract RejectingSpender is IERC1363Spender {
    function onApprovalReceived(address, uint256, bytes calldata) external pure override returns (bytes4) {
        return bytes4(0xdeadbeef);
    }
}

contract NonReceiver {}

// --- Tests ---

contract ERC1363Test is Test {
    MockERC1363 internal token;
    ValidReceiver internal receiver;
    RejectingReceiver internal rejecting;
    RevertingReceiver internal reverting;
    ValidSpender internal spender;
    RejectingSpender internal rejectingSpender;
    NonReceiver internal nonReceiver;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal constant INITIAL_SUPPLY = 1_000_000e18;

    function setUp() public {
        token = new MockERC1363("Test1363", "T1363");
        receiver = new ValidReceiver();
        rejecting = new RejectingReceiver();
        reverting = new RevertingReceiver();
        spender = new ValidSpender();
        rejectingSpender = new RejectingSpender();
        nonReceiver = new NonReceiver();

        token.mint(alice, INITIAL_SUPPLY);
    }

    // --- ERC165 ---

    function test_supportsInterface_IERC1363() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        // IERC1363 interface id = 0xb0202a11
        assertTrue(token.supportsInterface(bytes4(0xb0202a11)));
    }

    // --- transferAndCall ---

    function test_transferAndCall_toValidReceiver() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ValidReceiver.Received(alice, alice, 100e18, "");
        assertTrue(token.transferAndCall(address(receiver), 100e18));
        assertEq(token.balanceOf(address(receiver)), 100e18);
    }

    function test_transferAndCall_withData() public {
        bytes memory data = abi.encode("hello");
        vm.prank(alice);
        assertTrue(token.transferAndCall(address(receiver), 50e18, data));
        assertEq(token.balanceOf(address(receiver)), 50e18);
    }

    function test_transferAndCall_revert_toEOA() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidReceiver.selector, bob));
        token.transferAndCall(bob, 100e18);
    }

    function test_transferAndCall_revert_toRejectingReceiver() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidReceiver.selector, address(rejecting)));
        token.transferAndCall(address(rejecting), 100e18);
    }

    function test_transferAndCall_revert_toRevertingReceiver() public {
        vm.prank(alice);
        vm.expectRevert(RevertingReceiver.CustomRevert.selector);
        token.transferAndCall(address(reverting), 100e18);
    }

    function test_transferAndCall_revert_toNonReceiver() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidReceiver.selector, address(nonReceiver)));
        token.transferAndCall(address(nonReceiver), 100e18);
    }

    // --- transferFromAndCall ---

    function test_transferFromAndCall_toValidReceiver() public {
        vm.prank(alice);
        token.approve(bob, 200e18);

        vm.prank(bob);
        assertTrue(token.transferFromAndCall(alice, address(receiver), 200e18));
        assertEq(token.balanceOf(address(receiver)), 200e18);
    }

    function test_transferFromAndCall_withData() public {
        bytes memory data = abi.encode(uint256(42));
        vm.prank(alice);
        token.approve(bob, 100e18);

        vm.prank(bob);
        assertTrue(token.transferFromAndCall(alice, address(receiver), 100e18, data));
    }

    function test_transferFromAndCall_revert_toEOA() public {
        vm.prank(alice);
        token.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidReceiver.selector, address(0xBEEF)));
        token.transferFromAndCall(alice, address(0xBEEF), 100e18);
    }

    // --- approveAndCall ---

    function test_approveAndCall_toValidSpender() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ValidSpender.Approved(alice, 500e18, "");
        assertTrue(token.approveAndCall(address(spender), 500e18));
        assertEq(token.allowance(alice, address(spender)), 500e18);
    }

    function test_approveAndCall_withData() public {
        bytes memory data = "payload";
        vm.prank(alice);
        assertTrue(token.approveAndCall(address(spender), 300e18, data));
        assertEq(token.allowance(alice, address(spender)), 300e18);
    }

    function test_approveAndCall_revert_toEOA() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidSpender.selector, bob));
        token.approveAndCall(bob, 100e18);
    }

    function test_approveAndCall_revert_toRejectingSpender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidSpender.selector, address(rejectingSpender)));
        token.approveAndCall(address(rejectingSpender), 100e18);
    }

    // --- Fuzz ---

    function testFuzz_transferAndCall(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_SUPPLY);
        vm.prank(alice);
        token.transferAndCall(address(receiver), amount);
        assertEq(token.balanceOf(address(receiver)), amount);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
    }

    function testFuzz_approveAndCall(uint256 amount) public {
        vm.prank(alice);
        token.approveAndCall(address(spender), amount);
        assertEq(token.allowance(alice, address(spender)), amount);
    }

    // --- Zero amount ---

    function test_transferAndCall_zeroAmount() public {
        vm.prank(alice);
        assertTrue(token.transferAndCall(address(receiver), 0));
        assertEq(token.balanceOf(address(receiver)), 0);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
    }

    function test_approveAndCall_zeroAmount() public {
        vm.prank(alice);
        assertTrue(token.approveAndCall(address(spender), 0));
        assertEq(token.allowance(alice, address(spender)), 0);
    }

    // --- transferFromAndCall insufficient allowance ---

    function test_transferFromAndCall_revert_insufficientAllowance() public {
        vm.prank(alice);
        token.approve(bob, 50e18);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFromAndCall(alice, address(receiver), 100e18);
    }

    // --- transferAndCall insufficient balance ---

    function test_transferAndCall_revert_insufficientBalance() public {
        vm.prank(bob);
        vm.expectRevert();
        token.transferAndCall(address(receiver), 1);
    }

    // --- Receiver/spender that reverts with no reason ---

    function test_transferAndCall_revert_toNonReceiverContract() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1363.ERC1363InvalidReceiver.selector, address(nonReceiver)));
        token.transferAndCall(address(nonReceiver), 50e18, "data");
    }

    // --- transferFromAndCall preserves operator ---

    function test_transferFromAndCall_operatorIsCorrect() public {
        vm.prank(alice);
        token.approve(bob, 200e18);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit ValidReceiver.Received(bob, alice, 100e18, "");
        token.transferFromAndCall(alice, address(receiver), 100e18);
    }

    // --- Fuzz transferFromAndCall ---

    function testFuzz_transferFromAndCall(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_SUPPLY);
        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        token.transferFromAndCall(alice, address(receiver), amount);
        assertEq(token.balanceOf(address(receiver)), amount);
    }
}
