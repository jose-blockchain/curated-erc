// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC8004IdentityRegistry} from "./IERC8004IdentityRegistry.sol";
import {IERC8004ReputationRegistry} from "./IERC8004ReputationRegistry.sol";

/**
 * @title ERC8004ReputationRegistryUpgradeable
 * @dev Upgradeable ERC-8004 Reputation Registry using ERC-7201 namespaced storage.
 */
contract ERC8004ReputationRegistryUpgradeable is Initializable, OwnableUpgradeable, IERC8004ReputationRegistry {
    error ERC8004InvalidIdentityRegistry();
    error ERC8004SelfFeedbackNotAllowed(uint256 agentId);
    error ERC8004TooManyDecimals();
    error ERC8004ValueOutOfRange();
    error ERC8004InvalidFeedbackIndex();
    error ERC8004FeedbackAlreadyRevoked();
    error ERC8004EmptyResponseURI();
    error ERC8004ClientAddressesRequired();

    int128 private constant _MAX_ABS_VALUE = 1e38;

    struct Feedback {
        int128 value;
        uint8 valueDecimals;
        bool isRevoked;
        string tag1;
        string tag2;
    }

    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC8004Reputation
    struct ERC8004ReputationStorage {
        address identityRegistry;
        mapping(uint256 agentId => mapping(address client => mapping(uint64 index => Feedback))) feedback;
        mapping(uint256 agentId => mapping(address client => uint64)) lastIndex;
        mapping(
            uint256 agentId => mapping(address client => mapping(uint64 index => mapping(address responder => uint64)))
        ) responseCount;
        mapping(uint256 agentId => mapping(address client => mapping(uint64 index => address[]))) responders;
        mapping(
            uint256 agentId => mapping(address client => mapping(uint64 index => mapping(address responder => bool)))
        ) responderExists;
        mapping(uint256 agentId => address[]) clients;
        mapping(uint256 agentId => mapping(address client => bool)) clientExists;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC8004Reputation")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC8004ReputationStorageLocation =
        0xdd7edfb124aeedc7e162818d71f3fe8e679f9a348d82325b265951779fc9fa00;

    function _getERC8004ReputationStorage() private pure returns (ERC8004ReputationStorage storage $) {
        assembly {
            $.slot := ERC8004ReputationStorageLocation
        }
    }

    function __ERC8004ReputationRegistry_init(address identityRegistry_) internal onlyInitializing {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        __Ownable_init(msg.sender);
        _getERC8004ReputationStorage().identityRegistry = identityRegistry_;
    }

    function __ERC8004ReputationRegistry_init_unchained(address) internal onlyInitializing {}

    /// @inheritdoc IERC8004ReputationRegistry
    function initialize(address identityRegistry_) external {
        if (identityRegistry_ == address(0)) revert ERC8004InvalidIdentityRegistry();
        _getERC8004ReputationStorage().identityRegistry = identityRegistry_;
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function getIdentityRegistry() external view returns (address identityRegistry) {
        return _getERC8004ReputationStorage().identityRegistry;
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        if (valueDecimals > 18) revert ERC8004TooManyDecimals();
        if (value < -_MAX_ABS_VALUE || value > _MAX_ABS_VALUE) revert ERC8004ValueOutOfRange();
        if (IERC8004IdentityRegistry($.identityRegistry).isAuthorizedOrOwner(msg.sender, agentId)) {
            revert ERC8004SelfFeedbackNotAllowed(agentId);
        }

        uint64 currentIndex = ++$.lastIndex[agentId][msg.sender];
        Feedback storage fb = $.feedback[agentId][msg.sender][currentIndex];
        fb.value = value;
        fb.valueDecimals = valueDecimals;
        fb.isRevoked = false;
        fb.tag1 = tag1;
        fb.tag2 = tag2;

        if (!$.clientExists[agentId][msg.sender]) {
            $.clients[agentId].push(msg.sender);
            $.clientExists[agentId][msg.sender] = true;
        }

        emit NewFeedback(
            agentId,
            msg.sender,
            currentIndex,
            fb.value,
            fb.valueDecimals,
            tag1,
            tag1,
            fb.tag2,
            endpoint,
            feedbackURI,
            feedbackHash
        );
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        if (feedbackIndex == 0 || feedbackIndex > $.lastIndex[agentId][msg.sender]) {
            revert ERC8004InvalidFeedbackIndex();
        }
        Feedback storage fb = $.feedback[agentId][msg.sender][feedbackIndex];
        if (fb.isRevoked) revert ERC8004FeedbackAlreadyRevoked();
        fb.isRevoked = true;
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        if (feedbackIndex == 0) revert ERC8004InvalidFeedbackIndex();
        if (bytes(responseURI).length == 0) revert ERC8004EmptyResponseURI();
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        if (feedbackIndex > $.lastIndex[agentId][clientAddress]) revert ERC8004InvalidFeedbackIndex();

        if (!$.responderExists[agentId][clientAddress][feedbackIndex][msg.sender]) {
            $.responders[agentId][clientAddress][feedbackIndex].push(msg.sender);
            $.responderExists[agentId][clientAddress][feedbackIndex][msg.sender] = true;
        }
        $.responseCount[agentId][clientAddress][feedbackIndex][msg.sender]++;
        emit ResponseAppended(agentId, clientAddress, feedbackIndex, msg.sender, responseURI, responseHash);
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64) {
        return _getERC8004ReputationStorage().lastIndex[agentId][clientAddress];
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function readFeedback(uint256 agentId, address clientAddress, uint64 feedbackIndex)
        external
        view
        returns (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked)
    {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        if (feedbackIndex == 0 || feedbackIndex > $.lastIndex[agentId][clientAddress]) {
            revert ERC8004InvalidFeedbackIndex();
        }
        Feedback storage fb = $.feedback[agentId][clientAddress][feedbackIndex];
        return (fb.value, fb.valueDecimals, fb.tag1, fb.tag2, fb.isRevoked);
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function getSummary(uint256 agentId, address[] calldata clientAddresses, string calldata tag1, string calldata tag2)
        external
        view
        returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals)
    {
        if (clientAddresses.length == 0) revert ERC8004ClientAddressesRequired();
        return _computeSummary(agentId, clientAddresses, tag1, tag2);
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    )
        external
        view
        returns (
            address[] memory clients,
            uint64[] memory feedbackIndexes,
            int128[] memory values,
            uint8[] memory valueDecimals,
            string[] memory tag1s,
            string[] memory tag2s,
            bool[] memory revokedStatuses
        )
    {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        address[] memory clientList;
        if (clientAddresses.length > 0) {
            clientList = clientAddresses;
        } else {
            clientList = $.clients[agentId];
        }
        uint256 totalCount = _countFeedback($, agentId, clientList, tag1, tag2, includeRevoked);

        clients = new address[](totalCount);
        feedbackIndexes = new uint64[](totalCount);
        values = new int128[](totalCount);
        valueDecimals = new uint8[](totalCount);
        tag1s = new string[](totalCount);
        tag2s = new string[](totalCount);
        revokedStatuses = new bool[](totalCount);

        uint256 idx;
        bytes32 emptyHash = keccak256(bytes(""));
        bytes32 tag1Hash = keccak256(bytes(tag1));
        bytes32 tag2Hash = keccak256(bytes(tag2));

        for (uint256 i; i < clientList.length; i++) {
            uint64 lastIdx = $.lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = $.feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (emptyHash != tag1Hash && tag1Hash != keccak256(bytes(fb.tag1))) continue;
                if (emptyHash != tag2Hash && tag2Hash != keccak256(bytes(fb.tag2))) continue;

                clients[idx] = clientList[i];
                feedbackIndexes[idx] = j;
                values[idx] = fb.value;
                valueDecimals[idx] = fb.valueDecimals;
                tag1s[idx] = fb.tag1;
                tag2s[idx] = fb.tag2;
                revokedStatuses[idx] = fb.isRevoked;
                idx++;
            }
        }
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count) {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        if (clientAddress == address(0)) {
            address[] memory clients = $.clients[agentId];
            for (uint256 i; i < clients.length; i++) {
                uint64 lastIdx = $.lastIndex[agentId][clients[i]];
                for (uint64 j = 1; j <= lastIdx; j++) {
                    count += _countResponses($, agentId, clients[i], j, responders);
                }
            }
        } else if (feedbackIndex == 0) {
            uint64 lastIdx = $.lastIndex[agentId][clientAddress];
            for (uint64 j = 1; j <= lastIdx; j++) {
                count += _countResponses($, agentId, clientAddress, j, responders);
            }
        } else {
            count = _countResponses($, agentId, clientAddress, feedbackIndex, responders);
        }
    }

    /// @inheritdoc IERC8004ReputationRegistry
    function getClients(uint256 agentId) external view returns (address[] memory) {
        return _getERC8004ReputationStorage().clients[agentId];
    }

    function _countResponses(
        ERC8004ReputationStorage storage $,
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        address[] calldata responders
    ) private view returns (uint64 count) {
        if (responders.length == 0) {
            address[] memory allResponders = $.responders[agentId][clientAddress][feedbackIndex];
            for (uint256 k; k < allResponders.length; k++) {
                count += $.responseCount[agentId][clientAddress][feedbackIndex][allResponders[k]];
            }
        } else {
            for (uint256 k; k < responders.length; k++) {
                count += $.responseCount[agentId][clientAddress][feedbackIndex][responders[k]];
            }
        }
    }

    function _countFeedback(
        ERC8004ReputationStorage storage $,
        uint256 agentId,
        address[] memory clientList,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) private view returns (uint256 totalCount) {
        bytes32 emptyHash = keccak256(bytes(""));
        bytes32 tag1Hash = keccak256(bytes(tag1));
        bytes32 tag2Hash = keccak256(bytes(tag2));
        for (uint256 i; i < clientList.length; i++) {
            uint64 lastIdx = $.lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = $.feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (emptyHash != tag1Hash && tag1Hash != keccak256(bytes(fb.tag1))) continue;
                if (emptyHash != tag2Hash && tag2Hash != keccak256(bytes(fb.tag2))) continue;
                totalCount++;
            }
        }
    }

    function _computeSummary(uint256 agentId, address[] calldata clientList, string calldata tag1, string calldata tag2)
        private
        view
        returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals)
    {
        ERC8004ReputationStorage storage $ = _getERC8004ReputationStorage();
        bytes32 emptyHash = keccak256(bytes(""));
        bytes32 tag1Hash = keccak256(bytes(tag1));
        bytes32 tag2Hash = keccak256(bytes(tag2));
        int256 sum;
        uint64[19] memory decimalCounts;

        for (uint256 i; i < clientList.length; i++) {
            uint64 lastIdx = $.lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = $.feedback[agentId][clientList[i]][j];
                if (fb.isRevoked) continue;
                if (emptyHash != tag1Hash && tag1Hash != keccak256(bytes(fb.tag1))) continue;
                if (emptyHash != tag2Hash && tag2Hash != keccak256(bytes(fb.tag2))) continue;

                int256 factor = int256(10 ** uint256(18 - fb.valueDecimals));
                sum += fb.value * factor;
                decimalCounts[fb.valueDecimals]++;
                count++;
            }
        }

        if (count == 0) return (0, 0, 0);

        uint8 modeDecimals;
        uint64 maxCount;
        for (uint8 d; d <= 18; d++) {
            if (decimalCounts[d] > maxCount) {
                maxCount = decimalCounts[d];
                modeDecimals = d;
            }
        }

        int256 avgWad = sum / int256(uint256(count));
        summaryValue = int128(avgWad / int256(10 ** uint256(18 - modeDecimals)));
        summaryValueDecimals = modeDecimals;
    }
}
