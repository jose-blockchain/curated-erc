// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC2771
 * @dev Interface for ERC-2771 compliant contracts that accept meta-transactions
 * via a trusted forwarder.
 * See https://eips.ethereum.org/EIPS/eip-2771
 */
interface IERC2771 {
    /**
     * @dev Returns true if the given address is the trusted forwarder.
     * @param forwarder The address to check.
     */
    function isTrustedForwarder(address forwarder) external view returns (bool);
}
