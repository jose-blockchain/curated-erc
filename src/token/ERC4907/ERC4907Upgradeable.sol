// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC4907} from "./IERC4907.sol";

/**
 * @title ERC4907Upgradeable
 * @dev Upgradeable version of {ERC4907}. Uses ERC-7201 namespaced storage.
 */
abstract contract ERC4907Upgradeable is Initializable, ERC721Upgradeable, IERC4907 {
    struct UserInfo {
        address user;
        uint64 expires;
    }

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC4907
    struct ERC4907Storage {
        mapping(uint256 tokenId => UserInfo) _users;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC4907")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC4907StorageLocation =
        0xbb6c898d03b2a0b0f438ae2d429211d08bd1ca966e80a38e877ccd46aa410b00;

    function _getERC4907Storage() private pure returns (ERC4907Storage storage $) {
        assembly {
            $.slot := ERC4907StorageLocation
        }
    }

    function __ERC4907_init() internal onlyInitializing {}

    function __ERC4907_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC4907
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual {
        address owner = _requireOwned(tokenId);
        if (!_isAuthorized(owner, msg.sender, tokenId)) {
            revert ERC721InsufficientApproval(msg.sender, tokenId);
        }
        ERC4907Storage storage $ = _getERC4907Storage();
        $._users[tokenId] = UserInfo(user, expires);
        emit UpdateUser(tokenId, user, expires);
    }

    /// @inheritdoc IERC4907
    function userOf(uint256 tokenId) public view virtual returns (address) {
        ERC4907Storage storage $ = _getERC4907Storage();
        UserInfo storage info = $._users[tokenId];
        if (info.expires >= block.timestamp) {
            return info.user;
        }
        return address(0);
    }

    /// @inheritdoc IERC4907
    function userExpires(uint256 tokenId) public view virtual returns (uint256) {
        ERC4907Storage storage $ = _getERC4907Storage();
        return $._users[tokenId].expires;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != to && from != address(0)) {
            ERC4907Storage storage $ = _getERC4907Storage();
            delete $._users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
        return from;
    }
}
