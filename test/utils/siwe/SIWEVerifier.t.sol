// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SIWEVerifier} from "../../src/utils/cryptography/SIWEVerifier.sol";

contract SIWEVerifierTest is Test {
    SIWEVerifier internal verifier;
    uint256 internal signerKey = 0xa11ce;
    address internal signer;

    function setUp() public {
        signer = vm.addr(signerKey);
        verifier = new SIWEVerifier();
    }

    function createMessage(
        string memory domain,
        address addr,
        string memory uri,
        uint256 chainId,
        string memory nonce,
        string memory issuedAt,
        string memory statement
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            domain,
            " wants you to sign in with your Ethereum account:\n",
            _addressToString(addr),
            "\n\n",
            statement,
            "\n\nURI: ",
            uri,
            "\nVersion: 1\nChain ID: ",
            _toString(chainId),
            "\nNonce: ",
            nonce,
            "\nIssued At: ",
            issuedAt
        ));
    }

    function test_verifyValidMessage() public {
        string memory message = createMessage(
            "example.com",
            signer,
            "https://example.com/login",
            1,
            "abc123",
            "2024-01-01T00:00:00Z",
            "I accept the Terms of Service"
        );

        bytes32 messageHash = keccak256(bytes(message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        SIWEVerifier.VerificationParams memory params = SIWEVerifier.VerificationParams({
            expectedDomain: "example.com",
            expectedNonce: "abc123",
            expectedChainId: 1,
            currentTime: block.timestamp
        });

        SIWEVerifier.VerificationResult memory result = verifier.verify(
            message,
            signature,
            params
        );

        assertTrue(result.isValid);
        assertEq(result.message.signer, signer);
        assertEq(result.message.domain, "example.com");
        assertEq(result.message.chainId, 1);
        assertEq(result.message.nonce, "abc123");
    }

    function test_rejectWrongDomain() public {
        string memory message = createMessage(
            "example.com",
            signer,
            "https://example.com/login",
            1,
            "abc123",
            "2024-01-01T00:00:00Z",
            "I accept the Terms of Service"
        );

        bytes32 messageHash = keccak256(bytes(message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        SIWEVerifier.VerificationParams memory params = SIWEVerifier.VerificationParams({
            expectedDomain: "wrong.com",
            expectedNonce: "abc123",
            expectedChainId: 1,
            currentTime: block.timestamp
        });

        SIWEVerifier.VerificationResult memory result = verifier.verify(
            message,
            signature,
            params
        );

        assertFalse(result.isValid);
        assertEq(result.error, "Domain mismatch");
    }
}
