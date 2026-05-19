// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC8004IdentityRegistry} from "./IERC8004IdentityRegistry.sol";

/**
 * @title ERC8004IdentityRegistry
 * @dev ERC-8004 Identity Registry: ERC-721 agent identities with URI storage and optional metadata.
 */
contract ERC8004IdentityRegistry is ERC721URIStorage, Ownable, EIP712, IERC8004IdentityRegistry {
    error ERC8004ReservedMetadataKey(string metadataKey);
    error ERC8004NotAuthorized(uint256 agentId);
    error ERC8004InvalidWallet();
    error ERC8004SignatureExpired();
    error ERC8004DeadlineTooFar();
    error ERC8004InvalidWalletSignature();

    uint256 private _lastId;
    mapping(uint256 agentId => mapping(string metadataKey => bytes metadataValue)) private _metadata;

    bytes32 private constant _AGENT_WALLET_SET_TYPEHASH =
        keccak256("AgentWalletSet(uint256 agentId,address newWallet,address owner,uint256 deadline)");
    bytes4 private constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;
    uint256 private constant _MAX_DEADLINE_DELAY = 5 minutes;
    bytes32 private constant _RESERVED_AGENT_WALLET_KEY_HASH = keccak256("agentWallet");

    constructor() ERC721("AgentIdentity", "AGENT") EIP712("ERC8004IdentityRegistry", "1") Ownable(msg.sender) {}

    /// @inheritdoc IERC8004IdentityRegistry
    function register() external returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, "");
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function register(string calldata agentURI) external returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, agentURI);
        if (bytes(agentURI).length > 0) {
            _setTokenURI(agentId, agentURI);
        }
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function register(string calldata agentURI, MetadataEntry[] calldata metadata) external returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, agentURI);
        if (bytes(agentURI).length > 0) {
            _setTokenURI(agentId, agentURI);
        }
        for (uint256 i; i < metadata.length; i++) {
            _setAgentMetadata(agentId, metadata[i].metadataKey, metadata[i].metadataValue);
        }
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function getMetadata(uint256 agentId, string calldata metadataKey) external view returns (bytes memory) {
        _requireOwned(agentId);
        return _metadata[agentId][metadataKey];
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function setMetadata(uint256 agentId, string calldata metadataKey, bytes calldata metadataValue) external {
        _checkAuthorized(agentId);
        _setAgentMetadata(agentId, metadataKey, metadataValue);
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function setAgentURI(uint256 agentId, string calldata newURI) external {
        _checkAuthorized(agentId);
        _setTokenURI(agentId, newURI);
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function getAgentWallet(uint256 agentId) external view returns (address) {
        _requireOwned(agentId);
        return address(bytes20(_metadata[agentId]["agentWallet"]));
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external {
        _checkAuthorized(agentId);
        if (newWallet == address(0)) revert ERC8004InvalidWallet();
        if (block.timestamp > deadline) revert ERC8004SignatureExpired();
        if (deadline > block.timestamp + _MAX_DEADLINE_DELAY) revert ERC8004DeadlineTooFar();

        address owner = ownerOf(agentId);
        bytes32 structHash = keccak256(abi.encode(_AGENT_WALLET_SET_TYPEHASH, agentId, newWallet, owner, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        if (!_isValidWalletSignature(newWallet, digest, signature)) {
            revert ERC8004InvalidWalletSignature();
        }

        _metadata[agentId]["agentWallet"] = abi.encodePacked(newWallet);
        emit MetadataSet(agentId, "agentWallet", "agentWallet", abi.encodePacked(newWallet));
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function unsetAgentWallet(uint256 agentId) external {
        _checkAuthorized(agentId);
        delete _metadata[agentId]["agentWallet"];
        emit MetadataSet(agentId, "agentWallet", "agentWallet", "");
    }

    /// @inheritdoc IERC8004IdentityRegistry
    function isAuthorizedOrOwner(address spender, uint256 agentId) external view returns (bool) {
        address owner = _ownerOf(agentId);
        if (owner == address(0)) return false;
        return _isAuthorized(owner, spender, agentId);
    }

    function _mintAgent(address to, string memory agentURI) private returns (uint256 agentId) {
        agentId = _lastId++;
        _metadata[agentId]["agentWallet"] = abi.encodePacked(to);
        _safeMint(to, agentId);
        emit Registered(agentId, agentURI, to);
        emit MetadataSet(agentId, "agentWallet", "agentWallet", abi.encodePacked(to));
    }

    function _setAgentMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) private {
        if (keccak256(bytes(metadataKey)) == _RESERVED_AGENT_WALLET_KEY_HASH) {
            revert ERC8004ReservedMetadataKey(metadataKey);
        }
        _metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    function _checkAuthorized(uint256 agentId) private view {
        address owner = ownerOf(agentId);
        if (!_isAuthorized(owner, msg.sender, agentId)) {
            revert ERC8004NotAuthorized(agentId);
        }
    }

    function _isValidWalletSignature(address wallet, bytes32 digest, bytes calldata signature)
        private
        view
        returns (bool)
    {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signature);
        if (err == ECDSA.RecoverError.NoError && recovered == wallet) {
            return true;
        }
        if (wallet.code.length == 0) return false;
        (bool ok, bytes memory res) = wallet.staticcall(abi.encodeCall(IERC1271.isValidSignature, (digest, signature)));
        return ok && res.length >= 32 && abi.decode(res, (bytes4)) == _ERC1271_MAGIC_VALUE;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            delete _metadata[tokenId]["agentWallet"];
            emit MetadataSet(tokenId, "agentWallet", "agentWallet", "");
        }
        return super._update(to, tokenId, auth);
    }
}
