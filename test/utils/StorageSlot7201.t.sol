// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

contract StorageSlot7201Test is Test {
    /**
     * @dev Verifies the library against known OZ storage slot values.
     * OZ's ERC20 storage location for "openzeppelin.storage.ERC20" is:
     * 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00
     */
    function test_erc7201Slot_ERC20() public pure {
        bytes32 expected = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
        bytes32 result = StorageSlot7201.erc7201Slot("openzeppelin.storage.ERC20");
        assertEq(result, expected);
    }

    function test_erc7201Slot_ERC721() public pure {
        bytes32 expected = 0x80bb2b638cc20bc4d0a60d66940f3ab4a00c1d7b313497ca82fb0b4ab0079300;
        bytes32 result = StorageSlot7201.erc7201Slot("openzeppelin.storage.ERC721");
        assertEq(result, expected);
    }

    function test_erc7201Slot_endsWithZeroByte() public pure {
        bytes32 result = StorageSlot7201.erc7201Slot("test.namespace");
        assertEq(uint8(uint256(result) & 0xff), 0);
    }

    function test_erc7201Slot_differentNamespaces_differentSlots() public pure {
        bytes32 a = StorageSlot7201.erc7201Slot("namespace.A");
        bytes32 b = StorageSlot7201.erc7201Slot("namespace.B");
        assertTrue(a != b);
    }

    function testFuzz_erc7201Slot_lowByteAlwaysZero(string memory id) public pure {
        vm.assume(bytes(id).length > 0);
        bytes32 result = StorageSlot7201.erc7201Slot(id);
        assertEq(uint8(uint256(result) & 0xff), 0);
    }

    function test_reference_implementation() public pure {
        string memory id = "openzeppelin.storage.ERC20";
        bytes32 expected =
            keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
        bytes32 result = StorageSlot7201.erc7201Slot(id);
        assertEq(result, expected);
    }

    function testFuzz_matchesReference(string memory id) public pure {
        vm.assume(bytes(id).length > 0);
        bytes32 expected =
            keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
        bytes32 result = StorageSlot7201.erc7201Slot(id);
        assertEq(result, expected);
    }
}
