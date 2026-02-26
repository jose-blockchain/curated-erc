// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "./IERC1271.sol";

/**
 * @title ERC1271
 * @dev Abstract implementation of the {IERC1271} standard.
 *
 * Provides a default `isValidSignature` that recovers the signer via ECDSA and
 * compares it against the address returned by {_erc1271Signer}. Subclasses must
 * implement {_erc1271Signer} to return the authorized signer (e.g. the contract owner).
 *
 * The recovered signer can be an EOA. For more complex validation (multi-sig, threshold),
 * override {isValidSignature} directly.
 */
abstract contract ERC1271 is IERC1271 {
    bytes4 internal constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant _ERC1271_INVALID = 0xffffffff;

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes memory signature) external view virtual returns (bytes4) {
        if (_validateSignature(hash, signature)) {
            return _ERC1271_MAGIC_VALUE;
        }
        return _ERC1271_INVALID;
    }

    /**
     * @dev Returns the address authorized to sign on behalf of this contract.
     * Must be implemented by subclasses.
     */
    function _erc1271Signer() internal view virtual returns (address);

    /**
     * @dev Validates the signature against the authorized signer.
     * Override for custom validation logic (e.g. multi-sig).
     */
    function _validateSignature(bytes32 hash, bytes memory signature) internal view virtual returns (bool) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        return err == ECDSA.RecoverError.NoError && recovered == _erc1271Signer();
    }
}
