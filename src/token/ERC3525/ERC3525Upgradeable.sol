// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC3525} from "./IERC3525.sol";
import {IERC3525Receiver} from "./IERC3525Receiver.sol";

/**
 * @title ERC3525Upgradeable
 * @dev Upgradeable version of {ERC3525}. Uses ERC-7201 namespaced storage.
 * Same security hardening as ERC3525: reentrancy guard, CEI pattern.
 */
abstract contract ERC3525Upgradeable is
    Initializable,
    ContextUpgradeable,
    IERC3525,
    IERC721Metadata,
    IERC721Enumerable
{
    using Strings for uint256;
    using Strings for address;

    struct TokenData {
        uint256 id;
        uint256 slot;
        uint256 balance;
        address owner;
        address approved;
    }

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC3525
    struct ERC3525Storage {
        string _name;
        string _symbol;
        uint8 _decimals;
        uint256 _nextTokenId;
        uint256 _reentrancyStatus;
        TokenData[] _allTokens;
        mapping(uint256 tokenId => uint256) _allTokensIndex;
        mapping(uint256 tokenId => bool) _tokenExists;
        mapping(uint256 tokenId => mapping(address operator => uint256)) _valueAllowances;
        mapping(uint256 tokenId => address[]) _valueApprovedOperators;
        mapping(address owner => uint256[]) _ownedTokens;
        mapping(uint256 tokenId => uint256) _ownedTokensIndex;
        mapping(address owner => mapping(address operator => bool)) _operatorApprovals;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC3525")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC3525_STORAGE_LOCATION =
        0x0273b2faf1492a0f8780645e3fee9d302c46f67ebaa2de91c7d659d337187200;

    error ERC3525InvalidTokenId();
    error ERC3525InvalidReceiver();
    error ERC3525InsufficientBalance();
    error ERC3525SlotMismatch();
    error ERC3525InsufficientAllowance();
    error ERC3525InvalidOperator();
    error ERC3525TransferRejected();
    error ERC3525ReentrantCall();

    modifier nonReentrant() {
        ERC3525Storage storage $ = _getERC3525Storage();
        if ($._reentrancyStatus == 2) revert ERC3525ReentrantCall();
        $._reentrancyStatus = 2;
        _;
        $._reentrancyStatus = 1;
    }

    /**
     * @dev Initializes the contract. Use instead of constructor for upgradeable contracts.
     */
    function __ERC3525_init(string memory name_, string memory symbol_, uint8 decimals_) internal onlyInitializing {
        __ERC3525_init_unchained(name_, symbol_, decimals_);
    }

    /**
     * @dev Initializes the contract without the parent initializer.
     */
    function __ERC3525_init_unchained(string memory name_, string memory symbol_, uint8 decimals_)
        internal
        onlyInitializing
    {
        ERC3525Storage storage $ = _getERC3525Storage();
        $._name = name_;
        $._symbol = symbol_;
        $._decimals = decimals_;
        $._nextTokenId = 1;
        $._reentrancyStatus = 1;
    }

    /**
     * @dev Returns the ERC-7201 storage slot for this contract.
     */
    function _getERC3525Storage() private pure returns (ERC3525Storage storage $) {
        assembly {
            $.slot := ERC3525_STORAGE_LOCATION
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC3525).interfaceId
            || interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || interfaceId == type(IERC721Enumerable).interfaceId;
    }

    /// @inheritdoc IERC721Metadata
    function name() public view virtual override returns (string memory) {
        return _getERC3525Storage()._name;
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual override returns (string memory) {
        return _getERC3525Storage()._symbol;
    }

    /// @inheritdoc IERC3525
    function valueDecimals() public view virtual override returns (uint8) {
        return _getERC3525Storage()._decimals;
    }

    /// @inheritdoc IERC3525
    function balanceOf(uint256 tokenId) public view virtual override returns (uint256) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        ERC3525Storage storage $ = _getERC3525Storage();
        return $._allTokens[$._allTokensIndex[tokenId]].balance;
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        ERC3525Storage storage $ = _getERC3525Storage();
        address owner = $._allTokens[$._allTokensIndex[tokenId]].owner;
        if (owner == address(0)) revert ERC3525InvalidTokenId();
        return owner;
    }

    /// @inheritdoc IERC3525
    function slotOf(uint256 tokenId) public view virtual override returns (uint256) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        ERC3525Storage storage $ = _getERC3525Storage();
        return $._allTokens[$._allTokensIndex[tokenId]].slot;
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
     * @dev Returns the contract URI.
     */
    function contractURI() public view virtual returns (string memory) {
        string memory base = _baseURI();
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, "contract/", address(this).toHexString()));
        }
        return "";
    }

    /**
     * @dev Returns the slot URI for `slot`.
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
        return _getERC3525Storage()._valueAllowances[tokenId][operator];
    }

    /// @inheritdoc IERC3525
    function approve(uint256 tokenId, address operator, uint256 value) public payable virtual override {
        address owner = ownerOf(tokenId);
        if (operator == owner) revert ERC3525InvalidOperator();
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert ERC3525InvalidOperator();
        ERC3525Storage storage $ = _getERC3525Storage();
        $._valueAllowances[tokenId][operator] = value;
        if (value > 0 && !_hasValueApproval(tokenId, operator)) {
            $._valueApprovedOperators[tokenId].push(operator);
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
        ERC3525Storage storage $ = _getERC3525Storage();
        $._allTokens[$._allTokensIndex[tokenId]].approved = to;
        emit IERC721.Approval(owner, to, tokenId);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ERC3525InvalidTokenId();
        return _getERC3525Storage()._allTokens[_getERC3525Storage()._allTokensIndex[tokenId]].approved;
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved_) public virtual override {
        if (operator == _msgSender()) revert ERC3525InvalidOperator();
        _getERC3525Storage()._operatorApprovals[_msgSender()][operator] = approved_;
        emit IERC721.ApprovalForAll(_msgSender(), operator, approved_);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _getERC3525Storage()._operatorApprovals[owner][operator];
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert ERC3525InvalidTokenId();
        return _getERC3525Storage()._ownedTokens[owner].length;
    }

    /// @inheritdoc IERC721Enumerable
    function totalSupply() public view virtual override returns (uint256) {
        return _getERC3525Storage()._allTokens.length;
    }

    /// @inheritdoc IERC721Enumerable
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        ERC3525Storage storage $ = _getERC3525Storage();
        if (index >= $._allTokens.length) revert ERC3525InvalidTokenId();
        return $._allTokens[index].id;
    }

    /// @inheritdoc IERC721Enumerable
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        ERC3525Storage storage $ = _getERC3525Storage();
        if (index >= $._ownedTokens[owner].length) revert ERC3525InvalidTokenId();
        return $._ownedTokens[owner][index];
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
        ERC3525Storage storage $ = _getERC3525Storage();
        if (_isApprovedOrOwner(operator, tokenId)) return;
        uint256 current = $._valueAllowances[tokenId][operator];
        if (current != type(uint256).max && current < value) revert ERC3525InsufficientAllowance();
        if (current != type(uint256).max) {
            $._valueAllowances[tokenId][operator] = current - value;
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _getERC3525Storage()._tokenExists[tokenId];
    }

    function _findOrCreateTokenFor(address to, uint256 slot) internal virtual returns (uint256 tokenId) {
        ERC3525Storage storage $ = _getERC3525Storage();
        uint256 n = $._ownedTokens[to].length;
        for (uint256 i = 0; i < n; ++i) {
            uint256 id = $._ownedTokens[to][i];
            if ($._allTokens[$._allTokensIndex[id]].slot == slot) return id;
        }
        return _createTokenFor(to, slot);
    }

    function _createTokenFor(address to, uint256 slot) internal virtual returns (uint256 tokenId) {
        ERC3525Storage storage $ = _getERC3525Storage();
        tokenId = $._nextTokenId++;
        $._tokenExists[tokenId] = true;
        TokenData memory data = TokenData({id: tokenId, slot: slot, balance: 0, owner: to, approved: address(0)});
        $._allTokensIndex[tokenId] = $._allTokens.length;
        $._allTokens.push(data);
        _addTokenToOwner(to, tokenId);
        emit IERC721.Transfer(address(0), to, tokenId);
        emit SlotChanged(tokenId, 0, slot);
        return tokenId;
    }

    function _mint(address to, uint256 slot, uint256 value) internal virtual returns (uint256 tokenId) {
        if (to == address(0)) revert ERC3525InvalidReceiver();
        tokenId = _createTokenFor(to, slot);
        _addValue(tokenId, value);
    }

    function _addValue(uint256 tokenId, uint256 value) internal virtual {
        ERC3525Storage storage $ = _getERC3525Storage();
        $._allTokens[$._allTokensIndex[tokenId]].balance += value;
        emit TransferValue(0, tokenId, value);
    }

    function _addTokenToOwner(address to, uint256 tokenId) private {
        ERC3525Storage storage $ = _getERC3525Storage();
        $._ownedTokensIndex[tokenId] = $._ownedTokens[to].length;
        $._ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromOwner(address from, uint256 tokenId) private {
        ERC3525Storage storage $ = _getERC3525Storage();
        uint256[] storage owned = $._ownedTokens[from];
        uint256 idx = $._ownedTokensIndex[tokenId];
        uint256 last = owned.length - 1;
        uint256 lastId = owned[last];
        owned[idx] = lastId;
        $._ownedTokensIndex[lastId] = idx;
        delete $._ownedTokensIndex[tokenId];
        owned.pop();
    }

    function _transferValue(uint256 fromTokenId, uint256 toTokenId, uint256 value) internal virtual {
        if (!_exists(fromTokenId) || !_exists(toTokenId)) revert ERC3525InvalidTokenId();
        ERC3525Storage storage $ = _getERC3525Storage();
        TokenData storage fromData = $._allTokens[$._allTokensIndex[fromTokenId]];
        TokenData storage toData = $._allTokens[$._allTokensIndex[toTokenId]];
        if (fromData.balance < value) revert ERC3525InsufficientBalance();
        if (fromData.slot != toData.slot) revert ERC3525SlotMismatch();

        fromData.balance -= value;
        toData.balance += value;
        emit TransferValue(fromTokenId, toTokenId, value);

        if (_isContract(toData.owner)) {
            if (!_checkERC3525Received(fromTokenId, toTokenId, value, "")) {
                revert ERC3525TransferRejected();
            }
        }
    }

    function _transferToken(address from, address to, uint256 tokenId) internal virtual {
        if (ownerOf(tokenId) != from) revert ERC3525InvalidTokenId();
        if (to == address(0)) revert ERC3525InvalidReceiver();

        ERC3525Storage storage $ = _getERC3525Storage();
        $._allTokens[$._allTokensIndex[tokenId]].approved = address(0);
        _clearValueAllowances(tokenId);
        _removeTokenFromOwner(from, tokenId);
        _addTokenToOwner(to, tokenId);
        $._allTokens[$._allTokensIndex[tokenId]].owner = to;

        emit IERC721.Transfer(from, to, tokenId);
    }

    function _safeTransferToken(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transferToken(from, to, tokenId);
        if (_isContract(to) && !_checkERC721Received(from, to, tokenId, data)) {
            revert ERC3525InvalidReceiver();
        }
    }

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

    function _hasValueApproval(uint256 tokenId, address operator) private view returns (bool) {
        address[] storage ops = _getERC3525Storage()._valueApprovedOperators[tokenId];
        for (uint256 i = 0; i < ops.length; ++i) {
            if (ops[i] == operator) return true;
        }
        return false;
    }

    function _clearValueAllowances(uint256 tokenId) private {
        ERC3525Storage storage $ = _getERC3525Storage();
        address[] storage ops = $._valueApprovedOperators[tokenId];
        for (uint256 i = 0; i < ops.length; ++i) {
            delete $._valueAllowances[tokenId][ops[i]];
        }
        delete $._valueApprovedOperators[tokenId];
    }

    function _isContract(address addr) private view returns (bool) {
        return addr.code.length > 0;
    }
}
