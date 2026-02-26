// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC5192} from "./IERC5192.sol";

/**
 * @title ERC5192Upgradeable
 * @dev Upgradeable version of {ERC5192}. Uses ERC-7201 namespaced storage.
 */
abstract contract ERC5192Upgradeable is Initializable, ERC721Upgradeable, IERC5192 {
    error ERC5192TokenLocked(uint256 tokenId);
    error ERC5192TokenNotLocked(uint256 tokenId);

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC5192
    struct ERC5192Storage {
        mapping(uint256 tokenId => bool) _locked;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC5192")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC5192StorageLocation =
        0x5a6378b87e17a364b63e5a77dbe79462a636af110b6c7f8668dc1ffd4b1daf00;

    function _getERC5192Storage() private pure returns (ERC5192Storage storage $) {
        assembly {
            $.slot := ERC5192StorageLocation
        }
    }

    function __ERC5192_init() internal onlyInitializing {}

    function __ERC5192_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC5192
    function locked(uint256 tokenId) public view virtual returns (bool) {
        _requireOwned(tokenId);
        ERC5192Storage storage $ = _getERC5192Storage();
        return $._locked[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }

    function _lock(uint256 tokenId) internal virtual {
        _requireOwned(tokenId);
        ERC5192Storage storage $ = _getERC5192Storage();
        if ($._locked[tokenId]) {
            revert ERC5192TokenLocked(tokenId);
        }
        $._locked[tokenId] = true;
        emit Locked(tokenId);
    }

    function _unlock(uint256 tokenId) internal virtual {
        _requireOwned(tokenId);
        ERC5192Storage storage $ = _getERC5192Storage();
        if (!$._locked[tokenId]) {
            revert ERC5192TokenNotLocked(tokenId);
        }
        $._locked[tokenId] = false;
        emit Unlocked(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        ERC5192Storage storage $ = _getERC5192Storage();
        if (from != address(0) && to != address(0) && $._locked[tokenId]) {
            revert ERC5192TokenLocked(tokenId);
        }
        if (to == address(0)) {
            delete $._locked[tokenId];
        }
        return super._update(to, tokenId, auth);
    }
}
