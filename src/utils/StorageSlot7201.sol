// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StorageSlot7201
 * @dev Utility library for computing ERC-7201 namespaced storage locations.
 *
 * ERC-7201 defines a formula for deriving collision-free storage slots:
 *   keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
 *
 * This library provides a helper to compute that slot on-chain (useful for tests/tooling).
 * For production contracts, precompute the slot as a constant to save gas.
 *
 * See https://eips.ethereum.org/EIPS/eip-7201
 */
library StorageSlot7201 {
    /**
     * @dev Computes the ERC-7201 storage location for a given namespace identifier.
     * @param id The namespace identifier (e.g. "openzeppelin.storage.ERC20").
     * @return slot The derived storage slot.
     */
    function erc7201Slot(string memory id) internal pure returns (bytes32 slot) {
        assembly {
            let ptr := mload(0x40)
            let idLen := mload(id)
            let hash := keccak256(add(id, 0x20), idLen)
            mstore(ptr, sub(hash, 1))
            slot := and(keccak256(ptr, 0x20), not(0xff))
        }
    }
}
