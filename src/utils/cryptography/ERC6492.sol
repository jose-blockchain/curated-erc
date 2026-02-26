// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "./IERC1271.sol";

/**
 * @title ERC6492
 * @dev Universal signature validator supporting ERC-1271 and ERC-6492 (pre-deploy) signatures.
 * See https://eips.ethereum.org/EIPS/eip-6492
 *
 * Handles three cases:
 * 1. EOA signatures — ECDSA recovery
 * 2. Deployed contract signatures — ERC-1271 `isValidSignature`
 * 3. Pre-deploy contract signatures — deploys via factory, then ERC-1271
 *
 * The detection suffix `0x6492649264926492649264926492649264926492649264926492649264926492`
 * marks a signature as ERC-6492 wrapped.
 *
 * NOTE: This contract uses `CREATE` side-effects during validation. The `isValidSig`
 * function is intentionally non-view to allow factory deployment.
 */
library ERC6492 {
    bytes32 constant ERC6492_DETECTION_SUFFIX =
        0x6492649264926492649264926492649264926492649264926492649264926492;

    bytes4 constant ERC1271_MAGIC = 0x1626ba7e;

    error ERC6492DeployFailed();

    /**
     * @dev Validates a signature against `signer` for `hash`.
     * Supports EOA, ERC-1271, and ERC-6492 (pre-deploy) signatures.
     * @param signer The claimed signer address.
     * @param hash The signed hash.
     * @param signature The signature (possibly ERC-6492 wrapped).
     * @return True if valid.
     */
    function isValidSig(address signer, bytes32 hash, bytes calldata signature) internal returns (bool) {
        // Check for ERC-6492 wrapped signature (ends with detection suffix)
        if (
            signature.length >= 32
                && bytes32(signature[signature.length - 32:]) == ERC6492_DETECTION_SUFFIX
        ) {
            bytes calldata wrappedSig = signature[:signature.length - 32];
            (address factory, bytes memory factoryCalldata, bytes memory originalSig) =
                abi.decode(wrappedSig, (address, bytes, bytes));

            if (signer.code.length == 0) {
                // Deploy the contract
                (bool success,) = factory.call(factoryCalldata);
                if (!success || signer.code.length == 0) {
                    revert ERC6492DeployFailed();
                }
            } else {
                // Already deployed — try ERC-1271 first; if it fails, run the
                // factory "prepare" call and retry (EIP-6492 compliance).
                if (_checkERC1271(signer, hash, originalSig)) {
                    return true;
                }
                (bool success,) = factory.call(factoryCalldata);
                if (success) {
                    return _checkERC1271(signer, hash, originalSig);
                }
                return false;
            }

            return _checkERC1271(signer, hash, originalSig);
        }

        // Already deployed contract — try ERC-1271
        if (signer.code.length > 0) {
            return _checkERC1271(signer, hash, signature);
        }

        // EOA — ECDSA recovery
        return _checkECDSA(signer, hash, signature);
    }

    function _checkERC1271(address signer, bytes32 hash, bytes memory signature) private view returns (bool) {
        try IERC1271(signer).isValidSignature(hash, signature) returns (bytes4 magicValue) {
            return magicValue == ERC1271_MAGIC;
        } catch {
            return false;
        }
    }

    function _checkECDSA(address signer, bytes32 hash, bytes calldata signature) private pure returns (bool) {
        if (signature.length != 65) return false;
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        return err == ECDSA.RecoverError.NoError && recovered == signer;
    }
}
