// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC8004IdentityRegistry
 * @dev Interface for ERC-8004 Identity Registry (agent ERC-721 + on-chain metadata).
 */
interface IERC8004IdentityRegistry {
    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event MetadataSet(uint256 indexed agentId, string indexed indexedMetadataKey, string metadataKey, bytes metadataValue);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);

    function register() external returns (uint256 agentId);
    function register(string calldata agentURI) external returns (uint256 agentId);
    function register(string calldata agentURI, MetadataEntry[] calldata metadata) external returns (uint256 agentId);

    function getMetadata(uint256 agentId, string calldata metadataKey) external view returns (bytes memory);
    function setMetadata(uint256 agentId, string calldata metadataKey, bytes calldata metadataValue) external;
    function setAgentURI(uint256 agentId, string calldata newURI) external;

    function getAgentWallet(uint256 agentId) external view returns (address);
    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external;
    function unsetAgentWallet(uint256 agentId) external;

    function isAuthorizedOrOwner(address spender, uint256 agentId) external view returns (bool);
}
