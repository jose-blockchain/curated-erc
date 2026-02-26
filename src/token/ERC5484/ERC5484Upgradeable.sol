// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC5484} from "./IERC5484.sol";

/**
 * @title ERC5484Upgradeable
 * @dev Upgradeable version of {ERC5484}. Uses ERC-7201 namespaced storage.
 */
abstract contract ERC5484Upgradeable is Initializable, ERC721Upgradeable, IERC5484 {
    error ERC5484TransferDisabled();
    error ERC5484BurnUnauthorized(uint256 tokenId);

    struct TokenData {
        address issuer;
        BurnAuth auth;
    }

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC5484
    struct ERC5484Storage {
        mapping(uint256 tokenId => TokenData) _tokenData;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC5484")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC5484StorageLocation =
        0xf52fe779b91964094995287fb83d407644566a5d0f43000d4b3946580d550200;

    function _getERC5484Storage() private pure returns (ERC5484Storage storage $) {
        assembly {
            $.slot := ERC5484StorageLocation
        }
    }

    function __ERC5484_init() internal onlyInitializing {}

    function __ERC5484_init_unchained() internal onlyInitializing {}

    /// @inheritdoc IERC5484
    function burnAuth(uint256 tokenId) public view virtual returns (BurnAuth) {
        _requireOwned(tokenId);
        ERC5484Storage storage $ = _getERC5484Storage();
        return $._tokenData[tokenId].auth;
    }

    function issuerOf(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);
        ERC5484Storage storage $ = _getERC5484Storage();
        return $._tokenData[tokenId].issuer;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }

    function _issue(address to, uint256 tokenId, BurnAuth auth) internal virtual {
        _mint(to, tokenId);
        ERC5484Storage storage $ = _getERC5484Storage();
        $._tokenData[tokenId] = TokenData({issuer: msg.sender, auth: auth});
        emit Issued(msg.sender, to, tokenId, auth);
    }

    function _burnWithAuth(uint256 tokenId) internal virtual {
        ERC5484Storage storage $ = _getERC5484Storage();
        TokenData storage data = $._tokenData[tokenId];
        address owner = _requireOwned(tokenId);

        bool authorized;
        if (data.auth == BurnAuth.IssuerOnly) {
            authorized = msg.sender == data.issuer;
        } else if (data.auth == BurnAuth.OwnerOnly) {
            authorized = msg.sender == owner;
        } else if (data.auth == BurnAuth.Both) {
            authorized = msg.sender == data.issuer || msg.sender == owner;
        }

        if (!authorized) {
            revert ERC5484BurnUnauthorized(tokenId);
        }

        delete $._tokenData[tokenId];
        _burn(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert ERC5484TransferDisabled();
        }
        return super._update(to, tokenId, auth);
    }
}
