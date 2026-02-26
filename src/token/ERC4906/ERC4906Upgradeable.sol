// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC4906} from "./IERC4906.sol";

/**
 * @title ERC4906Upgradeable
 * @dev Upgradeable version of {ERC4906}. No storage needed (event-only extension).
 */
abstract contract ERC4906Upgradeable is Initializable, ERC721Upgradeable, IERC4906 {
    function __ERC4906_init() internal onlyInitializing {}

    function __ERC4906_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    function _emitMetadataUpdate(uint256 tokenId) internal virtual {
        emit MetadataUpdate(tokenId);
    }

    function _emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) internal virtual {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }
}
