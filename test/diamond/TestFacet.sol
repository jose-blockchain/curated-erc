// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

/**
 * @dev Test facet with its own storage slot. Exposes setValue/getValue for testing delegation.
 */
contract TestFacet {
    struct TestFacetStorage {
        uint256 value;
    }

    function _getStorage() private pure returns (TestFacetStorage storage s) {
        bytes32 slot = StorageSlot7201.erc7201Slot("curatedcontracts.storage.TestFacet");
        assembly {
            s.slot := slot
        }
    }

    function setValue(uint256 v) external {
        _getStorage().value = v;
    }

    function getValue() external view returns (uint256) {
        return _getStorage().value;
    }

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    /// @dev Callable as init in diamondCut to set initial value.
    function init(uint256 v) external {
        _getStorage().value = v;
    }
}
