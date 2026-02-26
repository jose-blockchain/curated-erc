// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1271
 * @dev Interface of the ERC-1271 standard signature validation method for contracts.
 * See https://eips.ethereum.org/EIPS/eip-1271
 */
interface IERC1271 {
    /**
     * @dev Returns whether the provided signature is valid for the provided hash.
     *
     * MUST return the bytes4 magic value `0x1626ba7e` when the signature is valid.
     * MUST NOT modify state.
     * MUST NOT return a value other than `0x1626ba7e` or `0xffffffff`.
     *
     * @param hash Hash of the data to be signed.
     * @param signature Signature byte array associated with `hash`.
     * @return magicValue `0x1626ba7e` if valid, `0xffffffff` otherwise.
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}
