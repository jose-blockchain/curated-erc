// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC3525} from "./IERC3525.sol";
import {IERC3525Receiver} from "./IERC3525Receiver.sol";

/**
 * @title ERC3525
 * @dev Secure reference implementation of ERC-3525 Semi-Fungible Token.
 * See https://eips.ethereum.org/EIPS/eip-3525
 *
 * SECURITY HARDENING (post Solv Protocol exploit, March 2025):
 * - ReentrancyGuard on all transfer paths that invoke callbacks. The Solv BitcoinReserveOffering
 *   exploit ($2.5M) exploited a consumer contract that minted in onERC721Received AND in mint(),
 *   causing double-mint. This ERC3525 implementation uses ReentrancyGuard as defense-in-depth.
 * - Strict Check-Effects-Interactions: state (balances, approvals, ownership) is updated and events
 *   emitted BEFORE any external callback (onERC3525Received, onERC721Received). Receivers cannot
 *   re-enter and observe inconsistent state.
 * - Receiver implementers: if your contract receives ERC-3525/721 and mints or does state changes,
 *   perform them ONLY in the callback OR ONLY after the transfer, never both. Use ReentrancyGuard
 *   on your mint/deposit functions.
 */
abstract contract ERC3525 is Context, ReentrancyGuard, IERC3525, IERC721Metadata, IERC721Enumerable {
    using Strings for uint256;
    using Strings for address;

    struct TokenData {
        uint256 id;
        uint256 slot;
        uint256 balance;
        address owner;
        address approved;
    }

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _nextTokenId = 1;

    TokenData[] private _allTokens;
    mapping(uint256 tokenId => uint256) private _allTokensIndex;
    mapping(uint256 tokenId => bool) private _tokenExists;
    mapping(uint256 tokenId => mapping(address operator => uint256)) private _valueAllowances;
    mapping(uint256 tokenId => address[]) private _valueApprovedOperators;
    mapping(address owner => uint256[]) private _ownedTokens;
    mapping(uint256 tokenId => uint256) private _ownedTokensIndex;
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    error ERC3525InvalidTokenId();
    error ERC3525InvalidReceiver();
    error ERC3525InsufficientBalance();
    error ERC3525SlotMismatch();
    error ERC3525InsufficientAllowance();
    error ERC3525InvalidOperator();
    error ERC3525TransferRejected();

    /**
     * @dev Initializes the contract by setting `name_`, `symbol_` and `decimals_`.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC3525).interfaceId
            || interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || interfaceId == type(IERC721Enumerable).interfaceId;
    }

    /// @inheritdoc IERC721Metadata
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IERC3525
    function valueDecimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IERC3525
    function balanceOf(uint256 tokenId) public view virtual override returns (uint256) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return _allTokens[_allTokensIndex[tokenId]].balance;
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        address owner = _allTokens[_allTokensIndex[tokenId]].owner;
        if (owner == address(0)) revert ERC3525InvalidTokenId();
        return owner;
    }

    /// @inheritdoc IERC3525
    function slotOf(uint256 tokenId) public view virtual override returns (uint256) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return _allTokens[_allTokensIndex[tokenId]].slot;
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return string(abi.encodePacked(_baseURI(), tokenId.toString()));
    }

    /**
     * @dev Base URI for computing {tokenURI}, {contractURI} and {slotURI}. Empty by default.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev Returns the contract URI. Override {_baseURI} to customize.
     */
    function contractURI() public view virtual returns (string memory) {
        string memory base = _baseURI();
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, "contract/", address(this).toHexString()));
        }
        return "";
    }

    /**
     * @dev Returns the slot URI for `slot`. Override {_baseURI} to customize.
     */
    function slotURI(uint256 slot) public view virtual returns (string memory) {
        string memory base = _baseURI();
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, "slot/", slot.toString()));
        }
        return "";
    }

    /// @inheritdoc IERC3525
    function allowance(uint256 tokenId, address operator) public view virtual override returns (uint256) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return _valueAllowances[tokenId][operator];
    }

    /// @inheritdoc IERC3525
    function approve(uint256 tokenId, address operator, uint256 value) public payable virtual override {
        address owner = ownerOf(tokenId);
        if (operator == owner) revert ERC3525InvalidOperator();
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert ERC3525InvalidOperator();
        _valueAllowances[tokenId][operator] = value;
        if (value > 0 && !_hasValueApproval(tokenId, operator)) {
            _valueApprovedOperators[tokenId].push(operator);
        }
        emit ApprovalValue(tokenId, operator, value);
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        if (to == owner) revert ERC3525InvalidOperator();
        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ERC3525InvalidOperator();
        }
        _allTokens[_allTokensIndex[tokenId]].approved = to;
        emit IERC721.Approval(owner, to, tokenId);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return _allTokens[_allTokensIndex[tokenId]].approved;
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved_) public virtual override {
        if (operator == _msgSender()) revert ERC3525InvalidOperator();
        _operatorApprovals[_msgSender()][operator] = approved_;
        emit IERC721.ApprovalForAll(_msgSender(), operator, approved_);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert ERC3525InvalidTokenId();
        return _ownedTokens[owner].length;
    }

    /// @inheritdoc IERC721Enumerable
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /// @inheritdoc IERC721Enumerable
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        if (index >= _allTokens.length) revert ERC3525InvalidTokenId();
        return _allTokens[index].id;
    }

    /// @inheritdoc IERC721Enumerable
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        if (index >= _ownedTokens[owner].length) revert ERC3525InvalidTokenId();
        return _ownedTokens[owner][index];
    }

    /// @inheritdoc IERC3525
    function transferFrom(uint256 fromTokenId, address to, uint256 value)
        public
        payable
        virtual
        override
        nonReentrant
        returns (uint256 toTokenId)
    {
        _spendValueAllowance(_msgSender(), fromTokenId, value);
        uint256 slot = slotOf(fromTokenId);
        toTokenId = _findOrCreateTokenFor(to, slot);
        _transferValue(fromTokenId, toTokenId, value);
    }

    /// @inheritdoc IERC3525
    function transferFrom(uint256 fromTokenId, uint256 toTokenId, uint256 value)
        public
        payable
        virtual
        override
        nonReentrant
    {
        _spendValueAllowance(_msgSender(), fromTokenId, value);
        _transferValue(fromTokenId, toTokenId, value);
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual override nonReentrant {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert ERC3525InvalidOperator();
        _transferToken(from, to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override
        nonReentrant
    {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert ERC3525InvalidOperator();
        _safeTransferToken(from, to, tokenId, data);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender;
    }

    function _spendValueAllowance(address operator, uint256 tokenId, uint256 value) internal virtual {
        if (_isApprovedOrOwner(operator, tokenId)) return;
        uint256 current = _valueAllowances[tokenId][operator];
        if (current != type(uint256).max && current < value) {
            revert ERC3525InsufficientAllowance();
        }
        if (current != type(uint256).max) {
            _valueAllowances[tokenId][operator] = current - value;
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenExists[tokenId];
    }

    /**
     * @dev Finds an existing token with `slot` owned by `to`, or creates a new one.
     */
    function _findOrCreateTokenFor(address to, uint256 slot) internal virtual returns (uint256 tokenId) {
        uint256 n = _ownedTokens[to].length;
        for (uint256 i = 0; i < n; ++i) {
            uint256 id = _ownedTokens[to][i];
            if (_allTokens[_allTokensIndex[id]].slot == slot) {
                return id;
            }
        }
        return _createTokenFor(to, slot);
    }

    /**
     * @dev Creates a new token for `to` with `slot`.
     */
    function _createTokenFor(address to, uint256 slot) internal virtual returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _tokenExists[tokenId] = true;
        TokenData memory data = TokenData({id: tokenId, slot: slot, balance: 0, owner: to, approved: address(0)});
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(data);
        _addTokenToOwner(to, tokenId);
        emit IERC721.Transfer(address(0), to, tokenId);
        emit SlotChanged(tokenId, 0, slot);
        return tokenId;
    }

    /**
     * @dev Mints a new token with `slot` and `value` to `to`.
     * Override to add access control (e.g. onlyMinter).
     */
    function _mint(address to, uint256 slot, uint256 value) internal virtual returns (uint256 tokenId) {
        if (to == address(0)) revert ERC3525InvalidReceiver();
        tokenId = _createTokenFor(to, slot);
        _addValue(tokenId, value);
    }

    /**
     * @dev Adds `value` to token `tokenId`.
     */
    function _addValue(uint256 tokenId, uint256 value) internal virtual {
        _allTokens[_allTokensIndex[tokenId]].balance += value;
        emit TransferValue(0, tokenId, value);
    }

    function _addTokenToOwner(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromOwner(address from, uint256 tokenId) private {
        uint256[] storage owned = _ownedTokens[from];
        uint256 idx = _ownedTokensIndex[tokenId];
        uint256 last = owned.length - 1;
        uint256 lastId = owned[last];
        owned[idx] = lastId;
        _ownedTokensIndex[lastId] = idx;
        delete _ownedTokensIndex[tokenId];
        owned.pop();
    }

    /**
     * @dev CEI: All state updates and events occur before external callbacks.
     */
    function _transferValue(uint256 fromTokenId, uint256 toTokenId, uint256 value) internal virtual {
        if (!_exists(fromTokenId) || !_exists(toTokenId)) revert ERC3525InvalidTokenId();
        TokenData storage fromData = _allTokens[_allTokensIndex[fromTokenId]];
        TokenData storage toData = _allTokens[_allTokensIndex[toTokenId]];
        if (fromData.balance < value) revert ERC3525InsufficientBalance();
        if (fromData.slot != toData.slot) revert ERC3525SlotMismatch();

        fromData.balance -= value;
        toData.balance += value;
        emit TransferValue(fromTokenId, toTokenId, value);

        if (_isContract(toData.owner)) {
            bool ok = _checkERC3525Received(fromTokenId, toTokenId, value, "");
            if (!ok) revert ERC3525TransferRejected();
        }
    }

    /**
     * @dev Transfers token `tokenId` from `from` to `to`.
     * Clears token and value approvals. State fully updated before any callback.
     */
    function _transferToken(address from, address to, uint256 tokenId) internal virtual {
        if (ownerOf(tokenId) != from) revert ERC3525InvalidTokenId();
        if (to == address(0)) revert ERC3525InvalidReceiver();

        _clearApprovals(tokenId);
        _clearValueAllowances(tokenId);
        _removeTokenFromOwner(from, tokenId);
        _addTokenToOwner(to, tokenId);
        _allTokens[_allTokensIndex[tokenId]].owner = to;
        _allTokens[_allTokensIndex[tokenId]].approved = address(0);

        emit IERC721.Transfer(from, to, tokenId);
    }

    /**
     * @dev Safely transfers token `tokenId` from `from` to `to`. Reverts if `to` is a contract
     * that does not implement {IERC721Receiver-onERC721Received}.
     */
    function _safeTransferToken(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transferToken(from, to, tokenId);
        if (_isContract(to)) {
            if (!_checkERC721Received(from, to, tokenId, data)) {
                revert ERC3525InvalidReceiver();
            }
        }
    }

    /**
     * @dev Clears token-level approval for `tokenId`.
     */
    function _clearApprovals(uint256 tokenId) private {
        _allTokens[_allTokensIndex[tokenId]].approved = address(0);
    }

    /**
     * @dev Returns whether `operator` has a value allowance entry for `tokenId`.
     */
    function _hasValueApproval(uint256 tokenId, address operator) private view returns (bool) {
        address[] storage ops = _valueApprovedOperators[tokenId];
        for (uint256 i = 0; i < ops.length; ++i) {
            if (ops[i] == operator) return true;
        }
        return false;
    }

    /**
     * @dev Clears all value allowances for `tokenId`. Called on token transfer.
     */
    function _clearValueAllowances(uint256 tokenId) private {
        address[] storage ops = _valueApprovedOperators[tokenId];
        for (uint256 i = 0; i < ops.length; ++i) {
            delete _valueAllowances[tokenId][ops[i]];
        }
        delete _valueApprovedOperators[tokenId];
    }

    /**
     * @dev Calls {IERC3525Receiver-onERC3525Received} on `to` if it implements the interface.
     * @return True if the transfer is accepted or the receiver is not a contract / does not implement the interface.
     */
    function _checkERC3525Received(uint256 fromTokenId, uint256 toTokenId, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool)
    {
        address to = ownerOf(toTokenId);
        if (!_isContract(to)) return true;
        try IERC165(to).supportsInterface(type(IERC3525Receiver).interfaceId) returns (bool ok) {
            if (!ok) return true;
            bytes4 ret = IERC3525Receiver(to).onERC3525Received(_msgSender(), fromTokenId, toTokenId, value, data);
            return ret == IERC3525Receiver.onERC3525Received.selector;
        } catch {
            return true;
        }
    }

    /**
     * @dev Calls {IERC721Receiver-onERC721Received} on `to`.
     * @return True if the transfer is accepted.
     */
    function _checkERC721Received(address from, address to, uint256 tokenId, bytes memory data)
        internal
        virtual
        returns (bool)
    {
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 ret) {
            return ret == IERC721Receiver.onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) return false;
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }

    function _isContract(address addr) private view returns (bool) {
        return addr.code.length > 0;
    }
}
