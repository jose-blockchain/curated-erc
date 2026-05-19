// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC8004ValidationRegistry} from "./IERC8004ValidationRegistry.sol";

/**
 * @title ERC8004ValidationRegistry
 * @dev ERC-8004 Validation Registry for validator request/response tracking.
 */
contract ERC8004ValidationRegistry is Ownable, IERC8004ValidationRegistry {
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

    address private _identityRegistry;
    mapping(bytes32 requestHash => ValidationStatus) private _validations;
    mapping(uint256 agentId => bytes32[]) private _agentValidations;
    mapping(address validator => bytes32[]) private _validatorRequests;

    constructor(address identityRegistry_, address initialOwner) Ownable(initialOwner) {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        _identityRegistry = identityRegistry_;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function initialize(address identityRegistry_) external {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        _identityRegistry = identityRegistry_;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getIdentityRegistry() external view returns (address identityRegistry) {
        return _identityRegistry;
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external {
        if (validatorAddress == address(0)) revert ERC8004InvalidValidator();
        if (_validations[requestHash].validatorAddress != address(0)) {
            revert ERC8004RequestExists(requestHash);
        }

        IERC721 registry = IERC721(_identityRegistry);
        address owner = registry.ownerOf(agentId);
        if (
            msg.sender != owner && !registry.isApprovedForAll(owner, msg.sender)
                && registry.getApproved(agentId) != msg.sender
        ) {
            revert ERC8004NotAuthorized(agentId);
        }

        _validations[requestHash] = ValidationStatus({
            validatorAddress: validatorAddress,
            agentId: agentId,
            response: 0,
            responseHash: bytes32(0),
            tag: "",
            lastUpdate: block.timestamp,
            hasResponse: false
        });
        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);

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
        ValidationStatus storage s = _validations[requestHash];
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
        ValidationStatus memory s = _validations[requestHash];
        if (s.validatorAddress == address(0)) revert ERC8004UnknownRequest(requestHash);
        return (s.validatorAddress, s.agentId, s.response, s.responseHash, s.tag, s.lastUpdate);
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getSummary(uint256 agentId, address[] calldata validatorAddresses, string calldata tag)
        external
        view
        returns (uint64 count, uint8 averageResponse)
    {
        bytes32[] storage requestHashes = _agentValidations[agentId];
        uint256 totalResponse;

        for (uint256 i; i < requestHashes.length; i++) {
            ValidationStatus storage s = _validations[requestHashes[i]];
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
        return _agentValidations[agentId];
    }

    /// @inheritdoc IERC8004ValidationRegistry
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return _validatorRequests[validatorAddress];
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
