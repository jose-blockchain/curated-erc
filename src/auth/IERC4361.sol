// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC4361
 * @dev Interface marker for Sign-In with Ethereum (ERC-4361) verification utilities.
 *
 * ERC-4361 defines an off-chain authentication message format. On-chain verification
 * is performed via {SIWE} and {SIWEVerifier} using ERC-191 signed message hashing.
 */
interface IERC4361 {
    /// @dev Emitted when a SIWE message is successfully verified on-chain.
    event SIWEVerified(address indexed signer, bytes32 indexed messageHash);
}
