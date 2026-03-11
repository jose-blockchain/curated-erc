// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC3525Receiver
 * @dev Interface for contracts that receive ERC-3525 value transfers.
 * See https://eips.ethereum.org/EIPS/eip-3525
 *
 * SECURITY: Implementers must follow Check-Effects-Interactions. Do NOT perform
 * state-changing operations that could be re-entered from the same transfer.
 * See Solv Protocol BitcoinReserveOffering exploit (March 2025): a contract
 * minted tokens in onERC721Received and again when execution returned to mint(),
 * causing double-mint. Use ReentrancyGuard and ensure callback logic does not
 * overlap with caller's post-callback logic.
 *
 * Note: ERC-165 identifier is 0x009ce20b.
 */
interface IERC3525Receiver {
    /**
     * @notice Handle receipt of ERC-3525 value transfer.
     * @param operator Address that initiated the transfer.
     * @param fromTokenId Token value was transferred from.
     * @param toTokenId Token value was transferred to.
     * @param value Amount transferred.
     * @param data Additional data.
     * @return bytes4(keccak256("onERC3525Received(...)")) to accept.
     */
    function onERC3525Received(
        address operator,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
