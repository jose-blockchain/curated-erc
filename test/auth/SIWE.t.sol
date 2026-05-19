// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SIWE} from "../../src/auth/SIWE.sol";
import {SIWEVerifier} from "../../src/auth/SIWEVerifier.sol";
import {IERC4361} from "../../src/auth/IERC4361.sol";

contract SIWETest is Test {
    uint256 internal constant _PRIVATE_KEY = 0xA11CE;
    address internal _signer;
    SIWEVerifier internal _verifier;
    string internal _message;

    function setUp() public {
        _signer = vm.addr(_PRIVATE_KEY);
        _verifier = new SIWEVerifier();
        _message = string.concat(
            "service.invalid wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "\n",
            "I accept the ServiceOrg Terms of Service: https://service.invalid/tos\n",
            "\n",
            "URI: https://service.invalid/login\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: 32891757\n",
            "Issued At: 2021-09-30T16:25:24.000Z"
        );
    }

    function _signMessage(string memory message) internal view returns (bytes memory signature) {
        bytes32 digest = SIWE.hashMessage(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_PRIVATE_KEY, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function test_hashMessage_matchesPersonalSign() public view {
        bytes32 expected = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n", vm.toString(bytes(_message).length), _message)
        );
        assertEq(SIWE.hashMessage(_message), expected);
    }

    function test_parseAddress() public view {
        address parsed = SIWE.parseAddress(_message);
        assertEq(parsed, _signer);
    }

    function test_verify_validSignature() public view {
        bytes memory sig = _signMessage(_message);
        SIWE.VerificationParams memory params = SIWE.VerificationParams({
            message: _message,
            signature: sig,
            signer: _signer,
            chainId: 1,
            domain: "service.invalid",
            nonce: "32891757",
            issuedAt: 0,
            expirationTime: 0,
            notBefore: 0
        });
        address recovered = SIWE.verify(params);
        assertEq(recovered, _signer);
    }

    function test_verifier_emitsEvent() public {
        bytes memory sig = _signMessage(_message);
        SIWE.VerificationParams memory params = SIWE.VerificationParams({
            message: _message,
            signature: sig,
            signer: address(0),
            chainId: 1,
            domain: "service.invalid",
            nonce: "32891757",
            issuedAt: 0,
            expirationTime: 0,
            notBefore: 0
        });

        vm.expectEmit(true, true, true, true);
        emit IERC4361.SIWEVerified(_signer, SIWE.hashMessage(_message));
        _verifier.verify(params);
    }

    function test_verify_revert_invalidSignature() public {
        SIWE.VerificationParams memory params = SIWE.VerificationParams({
            message: _message,
            signature: hex"11",
            signer: _signer,
            chainId: 0,
            domain: "",
            nonce: "",
            issuedAt: 0,
            expirationTime: 0,
            notBefore: 0
        });
        vm.expectRevert(SIWE.SIWEInvalidSignature.selector);
        this.exposedVerify(params);
    }

    function test_verify_revert_expired() public {
        vm.warp(10_000);
        bytes memory sig = _signMessage(_message);
        SIWE.VerificationParams memory params = SIWE.VerificationParams({
            message: _message,
            signature: sig,
            signer: _signer,
            chainId: 0,
            domain: "",
            nonce: "",
            issuedAt: 0,
            expirationTime: 9_999,
            notBefore: 0
        });
        vm.expectRevert(SIWE.SIWEExpired.selector);
        this.exposedVerify(params);
    }

    function testFuzz_verify_revert_wrongSigner(address wrongSigner) public {
        vm.assume(wrongSigner != _signer && wrongSigner != address(0));
        bytes memory sig = _signMessage(_message);
        SIWE.VerificationParams memory params = SIWE.VerificationParams({
            message: _message,
            signature: sig,
            signer: wrongSigner,
            chainId: 0,
            domain: "",
            nonce: "",
            issuedAt: 0,
            expirationTime: 0,
            notBefore: 0
        });
        vm.expectRevert(SIWE.SIWEInvalidSignature.selector);
        this.exposedVerify(params);
    }

    function exposedVerify(SIWE.VerificationParams memory params) external returns (address) {
        return SIWE.verify(params);
    }
}
