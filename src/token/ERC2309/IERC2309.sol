// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC2309
 * @dev Interface of the ERC-2309 Consecutive Transfer Extension.
 * See https://eips.ethereum.org/EIPS/eip-2309
 *
 * Provides a single event for notifying the creation/transfer of consecutive token IDs,
 * significantly reducing gas cost for batch minting (e.g. ERC721A-style).
 */
interface IERC2309 {
    /**
     * @dev Emitted when consecutive token IDs are transferred.
     * For minting, `fromAddress` is the zero address.
     * For burning, `toAddress` is the zero address.
     * @param fromTokenId The first token ID in the range.
     * @param toTokenId The last token ID in the range (inclusive).
     * @param fromAddress The sender (zero address for mints).
     * @param toAddress The recipient (zero address for burns).
     */
    event ConsecutiveTransfer(
        uint256 indexed fromTokenId, uint256 toTokenId, address indexed fromAddress, address indexed toAddress
    );
}
