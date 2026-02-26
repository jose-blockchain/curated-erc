// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC4907} from "./IERC4907.sol";

/**
 * @title ERC4907
 * @dev Implementation of the {IERC4907} Rental NFT standard.
 *
 * Extends {ERC721} to support a time-limited "user" role distinct from the owner.
 * The user role auto-expires based on a UNIX timestamp. On transfer, the user is cleared.
 */
abstract contract ERC4907 is ERC721, IERC4907 {
    struct UserInfo {
        address user;
        uint64 expires;
    }

    mapping(uint256 tokenId => UserInfo) private _users;

    /// @inheritdoc IERC4907
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual {
        address owner = _requireOwned(tokenId);
        if (!_isAuthorized(owner, msg.sender, tokenId)) {
            revert ERC721InsufficientApproval(msg.sender, tokenId);
        }
        _users[tokenId] = UserInfo(user, expires);
        emit UpdateUser(tokenId, user, expires);
    }

    /// @inheritdoc IERC4907
    function userOf(uint256 tokenId) public view virtual returns (address) {
        UserInfo storage info = _users[tokenId];
        if (info.expires >= block.timestamp) {
            return info.user;
        }
        return address(0);
    }

    /// @inheritdoc IERC4907
    function userExpires(uint256 tokenId) public view virtual returns (uint256) {
        return _users[tokenId].expires;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Clears user info on transfer. Mints do not set a user.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != to && from != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
        return from;
    }
}
