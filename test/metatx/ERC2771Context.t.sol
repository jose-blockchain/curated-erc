// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC2771Context} from "../../src/metatx/ERC2771Context.sol";

contract MockRecipient is ERC2771Context {
    event SenderRecovered(address sender);
    event DataRecovered(bytes data);

    constructor(address forwarder) ERC2771Context(forwarder) {}

    function execute() external {
        emit SenderRecovered(_msgSender());
        emit DataRecovered(_msgData());
    }

    function getSender() external view returns (address) {
        return _msgSender();
    }
}

contract ERC2771ContextTest is Test {
    MockRecipient internal recipient;

    address internal forwarder = makeAddr("forwarder");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        recipient = new MockRecipient(forwarder);
    }

    function test_trustedForwarder() public view {
        assertEq(recipient.trustedForwarder(), forwarder);
        assertTrue(recipient.isTrustedForwarder(forwarder));
        assertFalse(recipient.isTrustedForwarder(alice));
    }

    function test_msgSender_directCall() public {
        vm.prank(alice);
        assertEq(recipient.getSender(), alice);
    }

    function test_msgSender_viaForwarder() public {
        bytes memory callData = abi.encodeCall(MockRecipient.getSender, ());
        bytes memory suffixed = abi.encodePacked(callData, alice);

        vm.prank(forwarder);
        (bool success, bytes memory result) = address(recipient).call(suffixed);
        assertTrue(success);
        address recovered = abi.decode(result, (address));
        assertEq(recovered, alice);
    }

    function test_msgSender_forwarderWithoutSuffix() public {
        vm.prank(forwarder);
        assertEq(recipient.getSender(), forwarder);
    }

    function test_execute_emitsCorrectSender_viaForwarder() public {
        bytes memory callData = abi.encodeCall(MockRecipient.execute, ());
        bytes memory suffixed = abi.encodePacked(callData, bob);

        vm.prank(forwarder);
        vm.expectEmit(true, true, true, true);
        emit MockRecipient.SenderRecovered(bob);
        (bool success,) = address(recipient).call(suffixed);
        assertTrue(success);
    }

    function test_execute_emitsCorrectSender_directCall() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MockRecipient.SenderRecovered(alice);
        recipient.execute();
    }

    function testFuzz_msgSender_viaForwarder(address originalSender) public {
        vm.assume(originalSender != address(0));
        bytes memory callData = abi.encodeCall(MockRecipient.getSender, ());
        bytes memory suffixed = abi.encodePacked(callData, originalSender);

        vm.prank(forwarder);
        (bool success, bytes memory result) = address(recipient).call(suffixed);
        assertTrue(success);
        address recovered = abi.decode(result, (address));
        assertEq(recovered, originalSender);
    }

    function testFuzz_directCall_ignoresSuffix(address caller) public {
        vm.assume(caller != forwarder);
        vm.assume(caller != address(0));
        vm.prank(caller);
        assertEq(recipient.getSender(), caller);
    }

    // --- Short calldata from forwarder (< 20 bytes suffix means no extraction) ---

    function test_msgSender_forwarder_shortCalldata() public {
        // Call with only function selector (4 bytes), less than 20-byte suffix
        // The forwarder is msg.sender but calldata is too short, so _msgSender falls through
        // Actually, calldata for getSender() is 4 bytes, which < 20, so it should return forwarder
        vm.prank(forwarder);
        assertEq(recipient.getSender(), forwarder);
    }

    // --- Non-forwarder with appended suffix is ignored ---

    function test_nonForwarder_appendedSuffix_ignored() public {
        bytes memory callData = abi.encodeCall(MockRecipient.getSender, ());
        bytes memory suffixed = abi.encodePacked(callData, bob);

        vm.prank(alice);
        (bool success, bytes memory result) = address(recipient).call(suffixed);
        assertTrue(success);
        address recovered = abi.decode(result, (address));
        assertEq(recovered, alice);
    }

    // --- Multiple calls from forwarder ---

    function test_multipleCalls_viaForwarder() public {
        bytes memory callData = abi.encodeCall(MockRecipient.getSender, ());

        bytes memory suffixed1 = abi.encodePacked(callData, alice);
        vm.prank(forwarder);
        (bool s1, bytes memory r1) = address(recipient).call(suffixed1);
        assertTrue(s1);
        assertEq(abi.decode(r1, (address)), alice);

        bytes memory suffixed2 = abi.encodePacked(callData, bob);
        vm.prank(forwarder);
        (bool s2, bytes memory r2) = address(recipient).call(suffixed2);
        assertTrue(s2);
        assertEq(abi.decode(r2, (address)), bob);
    }

    // --- Forwarder is address(0) ---

    function test_zeroAddressForwarder() public {
        MockRecipient zeroRecipient = new MockRecipient(address(0));
        assertTrue(zeroRecipient.isTrustedForwarder(address(0)));
        assertFalse(zeroRecipient.isTrustedForwarder(alice));
    }
}
