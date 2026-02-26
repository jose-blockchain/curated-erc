// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC5484} from "./IERC5484.sol";

/**
 * @title ERC5484
 * @dev Implementation of the {IERC5484} Consensual Soulbound Tokens standard.
 *
 * Extends {ERC721} with non-transferability and a per-token burn authorization model.
 * Tokens are permanently soulbound (cannot be transferred after minting).
 * Burning is governed by the {BurnAuth} assigned at mint time.
 *
 * Subclasses use {_issue} to mint tokens with a specified burn authorization, and
 * {_burn} is access-controlled based on the token's {BurnAuth}.
 */
abstract contract ERC5484 is ERC721, IERC5484 {
    error ERC5484TransferDisabled();
    error ERC5484BurnUnauthorized(uint256 tokenId);

    struct TokenData {
        address issuer;
        BurnAuth auth;
    }

    mapping(uint256 tokenId => TokenData) private _tokenData;

    /// @inheritdoc IERC5484
    function burnAuth(uint256 tokenId) public view virtual returns (BurnAuth) {
        _requireOwned(tokenId);
        return _tokenData[tokenId].auth;
    }

    /**
     * @dev Returns the issuer of a token.
     */
    function issuerOf(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);
        return _tokenData[tokenId].issuer;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Issues (mints) a soulbound token to `to` with the given burn authorization.
     * Emits an {Issued} event.
     * @param to The recipient.
     * @param tokenId The token identifier.
     * @param auth The burn authorization for this token.
     */
    function _issue(address to, uint256 tokenId, BurnAuth auth) internal virtual {
        _mint(to, tokenId);
        _tokenData[tokenId] = TokenData({issuer: msg.sender, auth: auth});
        emit Issued(msg.sender, to, tokenId, auth);
    }

    /**
     * @dev Burns a soulbound token. Checks burn authorization:
     * - IssuerOnly: only the issuer can burn
     * - OwnerOnly: only the current owner can burn
     * - Both: either issuer or owner
     * - Neither: burn is permanently disabled
     */
    function _burnWithAuth(uint256 tokenId) internal virtual {
        TokenData storage data = _tokenData[tokenId];
        address owner = _requireOwned(tokenId);

        bool authorized;
        if (data.auth == BurnAuth.IssuerOnly) {
            authorized = msg.sender == data.issuer;
        } else if (data.auth == BurnAuth.OwnerOnly) {
            authorized = msg.sender == owner;
        } else if (data.auth == BurnAuth.Both) {
            authorized = msg.sender == data.issuer || msg.sender == owner;
        }
        // BurnAuth.Neither: authorized stays false

        if (!authorized) {
            revert ERC5484BurnUnauthorized(tokenId);
        }

        delete _tokenData[tokenId];
        _burn(tokenId);
    }

    /**
     * @dev Blocks all transfers except mint and burn. Soulbound tokens cannot be transferred.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert ERC5484TransferDisabled();
        }
        return super._update(to, tokenId, auth);
    }
}
