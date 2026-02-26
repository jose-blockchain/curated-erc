// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC4906} from "./IERC4906.sol";

/**
 * @title ERC4906
 * @dev Implementation of the {IERC4906} Metadata Update Extension for ERC-721.
 *
 * Provides internal helpers to emit {MetadataUpdate} and {BatchMetadataUpdate} events.
 * Subclasses call these when token metadata changes (e.g. after a reveal, URI update, etc.).
 */
abstract contract ERC4906 is ERC721, IERC4906 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Emits a {MetadataUpdate} event for a single token.
     */
    function _emitMetadataUpdate(uint256 tokenId) internal virtual {
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev Emits a {BatchMetadataUpdate} event for a range of tokens.
     * @param fromTokenId The first token in the range.
     * @param toTokenId The last token in the range (inclusive).
     */
    function _emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) internal virtual {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }
}
