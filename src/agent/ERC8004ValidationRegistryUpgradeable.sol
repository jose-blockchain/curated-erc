// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC8004ValidationRegistry} from "./IERC8004ValidationRegistry.sol";

/**
 * @title ERC8004ValidationRegistryUpgradeable
 * @dev Upgradeable ERC-8004 Validation Registry using ERC-7201 namespaced storage.
 */
contract ERC8004ValidationRegistryUpgradeable is Initializable, OwnableUpgradeable, IERC8004ValidationRegistry {
    error ERC8004InvalidIdentityRegistry();
    error ERC8004InvalidValidator();
    error ERC8004RequestExists(bytes32 requestHash);
    error ERC8004UnknownRequest(bytes32 requestHash);
    error ERC8004NotValidator(address caller, address expected);
    error ERC8004NotAuthorized(uint256 agentId);
    error ERC8004ResponseOutOfRange(uint8 response);

    struct ValidationStatus {
        address validatorAddress;
        uint256 agentId;
        uint8 response;
        bytes32 responseHash;
        string tag;
        uint256 lastUpdate;
        bool hasResponse;
    }

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC8004Validation
    struct ERC8004ValidationStorage {
        address identityRegistry;
        mapping(bytes32 requestHash => ValidationStatus) validations;
        mapping(uint256 agentId => bytes32[]) agentValidations;
        mapping(address validator => bytes32[]) validatorRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC8004Validation")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC8004ValidationStorageLocation =
        0x3a87cfa6c29247b8acdf819d9ffab5494b6b892e6022df044f917eb667157400;

    function _getERC8004ValidationStorage() private pure returns (ERC8004ValidationStorage storage $) {
        assembly {
            $.slot := ERC8004ValidationStorageLocation
        }
    }

    function __ERC8004ValidationRegistry_init(address identityRegistry_) internal onlyInitializing {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        __Ownable_init(msg.sender);
        _getERC8004ValidationStorage().identityRegistry = identityRegistry_;
    }

    function __ERC8004ValidationRegistry_init_unchained(address) internal onlyInitializing {}

    /// @inheritdoc IERC8004ValidationRegistry
    function initialize(address identityRegistry_) external {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        _getERC8004ValidationStorage().identityRegistry = identityRegistry_;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getIdentityRegistry() external view returns (address identityRegistry) {
        return _getERC8004ValidationStorage().identityRegistry;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external {
        ERC8004ValidationStorage storage $ = _getERC8004ValidationStorage();
        if (validatorAddress == address(0)) revert ERC8004InvalidValidator();
        if ($.validations[requestHash].validatorAddress != address(0)) {
            revert ERC8004RequestExists(requestHash);
        }

        IERC721 registry = IERC721($.identityRegistry);
        address owner = registry.ownerOf(agentId);
        if (
            msg.sender != owner && !registry.isApprovedForAll(owner, msg.sender)
                && registry.getApproved(agentId) != msg.sender
        ) {
            revert ERC8004NotAuthorized(agentId);
        }

        $.validations[requestHash] = ValidationStatus({
            validatorAddress: validatorAddress,
            agentId: agentId,
            response: 0,
            responseHash: bytes32(0),
            tag: "",
            lastUpdate: block.timestamp,
            hasResponse: false
        });
        $.agentValidations[agentId].push(requestHash);
        $.validatorRequests[validatorAddress].push(requestHash);

        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external {
        ERC8004ValidationStorage storage $ = _getERC8004ValidationStorage();
        ValidationStatus storage s = $.validations[requestHash];
        if (s.validatorAddress == address(0)) revert ERC8004UnknownRequest(requestHash);
        if (msg.sender != s.validatorAddress) revert ERC8004NotValidator(msg.sender, s.validatorAddress);
        if (response > 100) revert ERC8004ResponseOutOfRange(response);

        s.response = response;
        s.responseHash = responseHash;
        s.tag = tag;
        s.lastUpdate = block.timestamp;
        s.hasResponse = true;

        emit ValidationResponse(s.validatorAddress, s.agentId, requestHash, response, responseURI, responseHash, tag);
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getValidationStatus(bytes32 requestHash)
        external
        view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate
        )
    {
        ValidationStatus memory s = _getERC8004ValidationStorage().validations[requestHash];
        if (s.validatorAddress == address(0)) revert ERC8004UnknownRequest(requestHash);
        return (s.validatorAddress, s.agentId, s.response, s.responseHash, s.tag, s.lastUpdate);
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getSummary(uint256 agentId, address[] calldata validatorAddresses, string calldata tag)
        external
        view
        returns (uint64 count, uint8 averageResponse)
    {
        ERC8004ValidationStorage storage $ = _getERC8004ValidationStorage();
        bytes32[] storage requestHashes = $.agentValidations[agentId];
        uint256 totalResponse;

        for (uint256 i; i < requestHashes.length; i++) {
            ValidationStatus storage s = $.validations[requestHashes[i]];
            if (!s.hasResponse) continue;
            if (!_matchesValidator(s.validatorAddress, validatorAddresses)) continue;
            if (bytes(tag).length > 0 && keccak256(bytes(s.tag)) != keccak256(bytes(tag))) continue;

            totalResponse += s.response;
            count++;
        }

        averageResponse = count > 0 ? uint8(totalResponse / count) : 0;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory) {
        return _getERC8004ValidationStorage().agentValidations[agentId];
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return _getERC8004ValidationStorage().validatorRequests[validatorAddress];
    }

    function _matchesValidator(address validator, address[] calldata validatorAddresses)
        private
        pure
        returns (bool)
    {
        if (validatorAddresses.length == 0) return true;
        for (uint256 j; j < validatorAddresses.length; j++) {
            if (validator == validatorAddresses[j]) return true;
        }
        return false;
    }
}
