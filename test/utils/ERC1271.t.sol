// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1271} from "../../src/utils/cryptography/ERC1271.sol";

contract MockERC1271Wallet is ERC1271 {
    address private _owner;

    constructor(address owner_) {
        _owner = owner_;
    }

    function _erc1271Signer() internal view override returns (address) {
        return _owner;
    }
}

contract ERC1271Test is Test {
    MockERC1271Wallet internal wallet;

    uint256 internal signerKey = 0xA11CE;
    address internal signer;

    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_VALUE = 0xffffffff;

    function setUp() public {
        signer = vm.addr(signerKey);
        wallet = new MockERC1271Wallet(signer);
    }

    function test_validSignature() public view {
        bytes32 hash = keccak256("test message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(wallet.isValidSignature(hash, signature), MAGIC_VALUE);
    }

    function test_invalidSignature_wrongSigner() public view {
        bytes32 hash = keccak256("test message");
        uint256 wrongKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(wallet.isValidSignature(hash, signature), INVALID_VALUE);
    }

    function test_invalidSignature_wrongHash() public view {
        bytes32 hash = keccak256("test message");
        bytes32 wrongHash = keccak256("wrong message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(wallet.isValidSignature(wrongHash, signature), INVALID_VALUE);
    }

    function test_invalidSignature_malformedSig() public view {
        bytes32 hash = keccak256("test message");
        bytes memory badSig = hex"deadbeef";

        assertEq(wallet.isValidSignature(hash, badSig), INVALID_VALUE);
    }

    function test_invalidSignature_emptySig() public view {
        bytes32 hash = keccak256("test message");
        assertEq(wallet.isValidSignature(hash, ""), INVALID_VALUE);
    }

    function testFuzz_signatureValidation(bytes32 hash) public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(wallet.isValidSignature(hash, signature), MAGIC_VALUE);
    }

    function testFuzz_rejectsWrongSigner(uint256 wrongKey, bytes32 hash) public view {
        uint256 secp256k1Order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        wrongKey = bound(wrongKey, 1, secp256k1Order - 1);
        vm.assume(vm.addr(wrongKey) != signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(wallet.isValidSignature(hash, signature), INVALID_VALUE);
    }

    // --- Signature of length 64 (compact signature) ---

    function test_compactSignature_64bytes() public view {
        bytes32 hash = keccak256("test message");
        bytes memory badSig = new bytes(64);
        assertEq(wallet.isValidSignature(hash, badSig), INVALID_VALUE);
    }

    // --- Oversized signature ---

    function test_oversizedSignature() public view {
        bytes32 hash = keccak256("test message");
        bytes memory bigSig = new bytes(200);
        assertEq(wallet.isValidSignature(hash, bigSig), INVALID_VALUE);
    }

    // --- Wallet with address(0) signer rejects everything ---

    function test_zeroSigner_rejectsAll() public {
        MockERC1271Wallet zeroWallet = new MockERC1271Wallet(address(0));
        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(zeroWallet.isValidSignature(hash, signature), INVALID_VALUE);
    }
}
