// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC5192
 * @dev Interface of the ERC-5192 Minimal Soulbound NFTs standard.
 * See https://eips.ethereum.org/EIPS/eip-5192
 */
interface IERC5192 {
    /**
     * @dev Emitted when the locking status of a token changes.
     * @param tokenId The identifier of the token that was locked.
     */
    event Locked(uint256 tokenId);

    /**
     * @dev Emitted when the locking status of a token changes.
     * @param tokenId The identifier of the token that was unlocked.
     */
    event Unlocked(uint256 tokenId);

    /**
     * @dev Returns the locking status of a token.
     * If the token does not exist, the call MUST revert.
     * @param tokenId The identifier of the token.
     * @return True if the token is locked (soulbound), false otherwise.
     */
    function locked(uint256 tokenId) external view returns (bool);
}
