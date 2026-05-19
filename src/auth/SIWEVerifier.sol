// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4361} from "./IERC4361.sol";
import {SIWE} from "./SIWE.sol";

/**
 * @title SIWEVerifier
 * @dev Stateless on-chain verifier for ERC-4361 Sign-In with Ethereum messages.
 */
contract SIWEVerifier is IERC4361 {
    /// @dev Verifies a SIWE message and emits {SIWEVerified}.
    function verify(SIWE.VerificationParams calldata params) external returns (address signer) {
        signer = SIWE.verify(params);
        emit SIWEVerified(signer, SIWE.hashMessage(params.message));
    }
}
