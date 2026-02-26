// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC4906
 * @dev Interface of the ERC-4906 Metadata Update Extension.
 * See https://eips.ethereum.org/EIPS/eip-4906
 *
 * Emits events when token metadata changes, allowing marketplaces (e.g. OpenSea)
 * to refresh cached metadata without polling.
 */
interface IERC4906 is IERC165 {
    /**
     * @dev Emitted when the metadata of a single token is changed.
     * @param _tokenId The token whose metadata changed.
     */
    event MetadataUpdate(uint256 _tokenId);

    /**
     * @dev Emitted when the metadata of a range of tokens is changed.
     * @param _fromTokenId The first token in the range.
     * @param _toTokenId The last token in the range (inclusive).
     */
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}
