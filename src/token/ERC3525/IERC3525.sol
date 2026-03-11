// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IERC3525
 * @dev Semi-Fungible Token standard (ERC-3525).
 * See https://eips.ethereum.org/EIPS/eip-3525
 *
 * ERC-3525 combines ERC-721 identity with ERC-20-style value. Each token has:
 * - `id`: Unique token identity (ERC-721 compatible)
 * - `slot`: Fungibility group; tokens with same slot are fungible for value
 * - `value`: Quantitative amount (like ERC-20 balance)
 *
 * Note: ERC-165 identifier is 0xd5358140.
 */
interface IERC3525 is IERC165, IERC721 {
    /**
     * @dev Emitted when value is transferred between tokens (same slot).
     */
    event TransferValue(uint256 indexed fromTokenId, uint256 indexed toTokenId, uint256 value);

    /**
     * @dev Emitted when value-level approval is set or changed.
     */
    event ApprovalValue(uint256 indexed tokenId, address indexed operator, uint256 value);

    /**
     * @dev Emitted when the slot of a token is set or changed.
     */
    event SlotChanged(uint256 indexed tokenId, uint256 indexed oldSlot, uint256 indexed newSlot);

    /**
     * @notice Returns the number of decimals used to represent token values.
     * @return The number of decimals for value representation (e.g. 18).
     */
    function valueDecimals() external view returns (uint8);

    /**
     * @notice Returns the value (balance) of a token.
     * @param tokenId The token to query.
     * @return The value held by `tokenId`.
     */
    function balanceOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the slot of a token.
     * @param tokenId The token to query.
     * @return The slot that `tokenId` belongs to.
     */
    function slotOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Approves `operator` to manage up to `value` of `tokenId`.
     * @param tokenId The token to approve.
     * @param operator The operator to approve.
     * @param value The maximum value `operator` is allowed to manage.
     */
    function approve(uint256 tokenId, address operator, uint256 value) external payable;

    /**
     * @notice Returns the value allowance of `operator` for `tokenId`.
     * @param tokenId The token to query.
     * @param operator The operator to query.
     * @return The current allowance.
     */
    function allowance(uint256 tokenId, address operator) external view returns (uint256);

    /**
     * @notice Transfers value from one token to another (same slot).
     * @param fromTokenId The token to transfer value from.
     * @param toTokenId The token to transfer value to.
     * @param value The amount to transfer.
     */
    function transferFrom(uint256 fromTokenId, uint256 toTokenId, uint256 value) external payable;

    /**
     * @notice Transfers value from a token to an address. Creates or reuses a token for the receiver.
     * @param fromTokenId The token to transfer value from.
     * @param to The address to receive the value.
     * @param value The amount to transfer.
     * @return toTokenId The token that received the value.
     */
    function transferFrom(uint256 fromTokenId, address to, uint256 value) external payable returns (uint256 toTokenId);
}
