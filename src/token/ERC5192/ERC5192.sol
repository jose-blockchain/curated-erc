// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC5192} from "./IERC5192.sol";

/**
 * @title ERC5192
 * @dev Implementation of the {IERC5192} Minimal Soulbound NFTs standard.
 *
 * Extends {ERC721} to support non-transferable (soulbound) tokens. Each token has a `locked`
 * status. When locked, `_update` reverts on transfer (mints and burns are still permitted).
 *
 * Subclasses control locking policy by calling {_lock} and {_unlock}.
 */
abstract contract ERC5192 is ERC721, IERC5192 {
    error ERC5192TokenLocked(uint256 tokenId);
    error ERC5192TokenNotLocked(uint256 tokenId);

    mapping(uint256 tokenId => bool) private _locked;

    /// @inheritdoc IERC5192
    function locked(uint256 tokenId) public view virtual returns (bool) {
        _requireOwned(tokenId);
        return _locked[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Locks a token, making it non-transferable.
     * Emits a {Locked} event.
     */
    function _lock(uint256 tokenId) internal virtual {
        _requireOwned(tokenId);
        if (_locked[tokenId]) {
            revert ERC5192TokenLocked(tokenId);
        }
        _locked[tokenId] = true;
        emit Locked(tokenId);
    }

    /**
     * @dev Unlocks a token, making it transferable again.
     * Emits an {Unlocked} event.
     */
    function _unlock(uint256 tokenId) internal virtual {
        _requireOwned(tokenId);
        if (!_locked[tokenId]) {
            revert ERC5192TokenNotLocked(tokenId);
        }
        _locked[tokenId] = false;
        emit Unlocked(tokenId);
    }

    /**
     * @dev Override of {ERC721-_update}. Prevents transfers of locked tokens.
     * Mints (from == address(0)) and burns (to == address(0)) are always allowed.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0) && _locked[tokenId]) {
            revert ERC5192TokenLocked(tokenId);
        }
        if (to == address(0)) {
            delete _locked[tokenId];
        }
        return super._update(to, tokenId, auth);
    }
}
