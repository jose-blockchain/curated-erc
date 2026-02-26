// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1271} from "./IERC1271.sol";

/**
 * @title ERC1271Upgradeable
 * @dev Upgradeable version of {ERC1271}.
 *
 * No namespaced storage needed as this contract is stateless; the signer is
 * provided by subclasses via {_erc1271Signer}.
 */
abstract contract ERC1271Upgradeable is Initializable, IERC1271 {
    bytes4 internal constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant _ERC1271_INVALID = 0xffffffff;

    function __ERC1271_init() internal onlyInitializing {}

    function __ERC1271_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes memory signature) external view virtual returns (bytes4) {
        if (_validateSignature(hash, signature)) {
            return _ERC1271_MAGIC_VALUE;
        }
        return _ERC1271_INVALID;
    }

    function _erc1271Signer() internal view virtual returns (address);

    function _validateSignature(bytes32 hash, bytes memory signature) internal view virtual returns (bool) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        return err == ECDSA.RecoverError.NoError && recovered == _erc1271Signer();
    }
}
