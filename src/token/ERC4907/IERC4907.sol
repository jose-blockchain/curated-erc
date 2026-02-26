// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IERC4907
 * @dev Interface of the ERC-4907 Rental NFT standard.
 * See https://eips.ethereum.org/EIPS/eip-4907
 *
 * Adds a time-limited "user" role to ERC-721, separating ownership from usage rights.
 */
interface IERC4907 is IERC721 {
    /**
     * @dev Emitted when the user of an NFT is changed or the user expiry is changed.
     */
    event UpdateUser(uint256 indexed tokenId, address indexed user, uint64 expires);

    /**
     * @dev Sets the `user` and `expires` for a token. The zero address clears the user.
     * Only callable by the token owner or approved operator.
     * @param tokenId The token to set the user for.
     * @param user The new user of the token.
     * @param expires UNIX timestamp when the user role expires.
     */
    function setUser(uint256 tokenId, address user, uint64 expires) external;

    /**
     * @dev Returns the current user of a token. Returns the zero address if unset or expired.
     * @param tokenId The token to query.
     * @return The user address.
     */
    function userOf(uint256 tokenId) external view returns (address);

    /**
     * @dev Returns the expiry timestamp of the user role for a token.
     * @param tokenId The token to query.
     * @return The expiry UNIX timestamp.
     */
    function userExpires(uint256 tokenId) external view returns (uint256);
}
