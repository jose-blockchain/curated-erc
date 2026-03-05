// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

/**
 * @dev Second test facet (different storage namespace). Used for replace tests.
 */
contract TestFacet2 {
    struct TestFacet2Storage {
        uint256 value;
    }

    function _getStorage() private pure returns (TestFacet2Storage storage s) {
        bytes32 slot = StorageSlot7201.erc7201Slot("curatedcontracts.storage.TestFacet2");
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
}
