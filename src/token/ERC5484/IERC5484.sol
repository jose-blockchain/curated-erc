// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC5484
 * @dev Interface of the ERC-5484 Consensual Soulbound Tokens standard.
 * See https://eips.ethereum.org/EIPS/eip-5484
 *
 * Extends ERC-721 with a burn authorization model. Each token has a {BurnAuth} that
 * determines who may burn it: the issuer, the owner, both, or neither.
 */
interface IERC5484 {
    /**
     * @dev Defines who has the authority to burn a soulbound token.
     */
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    /**
     * @dev Emitted when a soulbound token is issued.
     * @param from The issuer address.
     * @param to The recipient address.
     * @param tokenId The token identifier.
     * @param burnAuth The burn authorization for this token.
     */
    event Issued(address indexed from, address indexed to, uint256 indexed tokenId, BurnAuth burnAuth);

    /**
     * @dev Returns the burn authorization for a token.
     * @param tokenId The token to query.
     * @return The {BurnAuth} value.
     */
    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}
