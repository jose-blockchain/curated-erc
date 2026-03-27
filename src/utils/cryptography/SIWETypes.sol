// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SIWE Types
 * @dev Data structures for ERC-4361 (Sign-In with Ethereum) message parsing
 */
library SIWETypes {
    /**
     * @dev Parsed SIWE message fields
     * @param domain The RFC 3986 authority that is requesting the signing
     * @param address The Ethereum address performing the signing
     * @param statement Optional human-readable assertion
     * @param uri RFC 3986 URI referring to the resource that is the subject of the signing
     * @param version Current version of the SIWE message, must be 1
     * @param chainId EIP-155 Chain ID to which the session is bound
     * @param nonce Randomized token to prevent replay attacks
     * @param issuedAt ISO 8601 datetime string of when the message was generated
     * @param expirationTime Optional ISO 8601 datetime string of when the message expires
     * @param notBefore Optional ISO 8601 datetime string of when the message becomes valid
     * @param requestId Optional system-specific identifier for the request
     * @param resources Optional list of resources the user is requesting access to
     */
    struct SIWEMessage {
        string domain;
        address userAddress;
        string statement;
        string uri;
        uint256 version;
        uint256 chainId;
        string nonce;
        uint256 issuedAt;      // Unix timestamp (converted from ISO 8601)
        uint256 expirationTime; // Unix timestamp (0 if not set)
        uint256 notBefore;     // Unix timestamp (0 if not set)
        string requestId;
        string[] resources;
    }

    /**
     * @dev Verification parameters
     * @param expectedDomain The domain to match against
     * @param expectedNonce The nonce to validate
     * @param expectedChainId The chain ID to validate
     * @param currentTime Current block timestamp for time-based validation
     */
    struct VerificationParams {
        string expectedDomain;
        string expectedNonce;
        uint256 expectedChainId;
        uint256 currentTime;
    }

    /**
     * @dev Verification result
     * @param isValid Whether the signature is valid
     * @param message The parsed message (if parsing succeeded)
     * @param error Error message if verification failed
     */
    struct VerificationResult {
        bool isValid;
        SIWEMessage message;
        string error;
    }
}
