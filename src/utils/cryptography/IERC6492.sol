// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC6492
 * @dev Interface for ERC-6492 signature validation, including pre-deploy (counterfactual) contracts.
 * See https://eips.ethereum.org/EIPS/eip-6492
 *
 * ERC-6492 extends ERC-1271 to handle signatures from smart contract wallets that have not
 * yet been deployed. A wrapped signature contains:
 *   abi.encode(address factory, bytes factoryCalldata, bytes originalSignature) ++ ERC6492_DETECTION_SUFFIX
 *
 * The validator deploys the contract via the factory, then calls ERC-1271 `isValidSignature`.
 */
interface IERC6492 {
    /**
     * @dev Validates a signature, supporting both deployed and pre-deploy (counterfactual) signers.
     * @param signer The claimed signer address.
     * @param hash The hash that was signed.
     * @param signature The signature bytes (possibly ERC-6492 wrapped).
     * @return True if the signature is valid.
     */
    function isValidSig(address signer, bytes32 hash, bytes calldata signature) external returns (bool);
}
