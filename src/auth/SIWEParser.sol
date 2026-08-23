// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SIWE} from "./SIWE.sol";

/**
 * @title SIWEParser
 * @dev Stateless helper that exposes {SIWE-parse} for on-chain callers.
 *
 * Does not verify signatures. Use {SIWEVerifier} or {SIWE-verify} for that.
 * Has no storage and does not emit events.
 */
contract SIWEParser {
    /// @dev Parses an ERC-4361 SIWE plaintext message into structured fields.
    function parse(string calldata message) external pure returns (SIWE.Message memory parsed) {
        return SIWE.parse(message);
    }
}
