// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamond} from "./IDiamond.sol";
import {IDiamondLoupe} from "./IDiamondLoupe.sol";
import {StorageSlot7201} from "../utils/StorageSlot7201.sol";

/**
 * @title LibDiamond
 * @dev Internal storage and diamond cut logic for EIP-2535 Diamonds.
 * Storage uses ERC-7201 namespaced slot to avoid clashes.
 */
library LibDiamond {
    function _diamondStorageSlot() private pure returns (bytes32) {
        return StorageSlot7201.erc7201Slot("curatedcontracts.storage.Diamond");
    }

    struct DiamondStorage {
        address contractOwner;
        mapping(bytes4 => address) selectorToFacet;
        address[] facetAddresses;
        mapping(address => bytes4[]) facetSelectors;
    }

    error LibDiamondOnlyOwner();
    error LibDiamondSelectorAlreadyExists(bytes4 selector);
    error LibDiamondSelectorNotFound(bytes4 selector);
    error LibDiamondSelectorNotReplaced(bytes4 selector);
    error LibDiamondImmutableSelector(bytes4 selector);
    error LibDiamondInvalidFacetCut();
    error LibDiamondInitReverted(bytes reason);

    function getDiamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 slot = _diamondStorageSlot();
        assembly {
            ds.slot := slot
        }
    }

    function enforceIsContractOwner() internal view {
        DiamondStorage storage ds = getDiamondStorage();
        if (msg.sender != ds.contractOwner) revert LibDiamondOnlyOwner();
    }

    function setContractOwner(address _owner) internal {
        DiamondStorage storage ds = getDiamondStorage();
        ds.contractOwner = _owner;
    }

    function diamondCut(IDiamond.FacetCut[] memory diamondCut_, address init, bytes memory calldata_) internal {
        DiamondStorage storage ds = getDiamondStorage();
        for (uint256 i = 0; i < diamondCut_.length; i++) {
            IDiamond.FacetCutAction action = diamondCut_[i].action;
            address facetAddr = diamondCut_[i].facetAddress;
            bytes4[] memory selectors = diamondCut_[i].functionSelectors;

            if (action == IDiamond.FacetCutAction.Add) {
                _addFacet(ds, facetAddr, selectors);
            } else if (action == IDiamond.FacetCutAction.Replace) {
                _replaceFacet(ds, facetAddr, selectors);
            } else if (action == IDiamond.FacetCutAction.Remove) {
                _removeFacet(ds, selectors);
            } else {
                revert LibDiamondInvalidFacetCut();
            }
        }

        if (init != address(0)) {
            _initDiamond(init, calldata_);
        }
    }

    function _addFacet(DiamondStorage storage ds, address facet, bytes4[] memory selectors) private {
        if (facet == address(0)) revert LibDiamondInvalidFacetCut();
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            if (ds.selectorToFacet[sel] != address(0)) revert LibDiamondSelectorAlreadyExists(sel);
            ds.selectorToFacet[sel] = facet;
            _addSelectorToFacet(ds, facet, sel);
        }
    }

    function _replaceFacet(DiamondStorage storage ds, address facet, bytes4[] memory selectors) private {
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            address oldFacet = ds.selectorToFacet[sel];
            if (oldFacet == address(0)) revert LibDiamondSelectorNotFound(sel);
            if (oldFacet == facet) revert LibDiamondSelectorNotReplaced(sel);
            ds.selectorToFacet[sel] = facet;
            _removeSelectorFromFacet(ds, oldFacet, sel);
            _addSelectorToFacet(ds, facet, sel);
        }
    }

    function _removeFacet(DiamondStorage storage ds, bytes4[] memory selectors) private {
        address diamondAddress = address(this);
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            address facet = ds.selectorToFacet[sel];
            if (facet == address(0)) revert LibDiamondSelectorNotFound(sel);
            if (facet == diamondAddress) revert LibDiamondImmutableSelector(sel);
            delete ds.selectorToFacet[sel];
            _removeSelectorFromFacet(ds, facet, sel);
        }
    }

    function _addSelectorToFacet(DiamondStorage storage ds, address facet, bytes4 selector) private {
        bytes4[] storage s = ds.facetSelectors[facet];
        if (s.length == 0) {
            ds.facetAddresses.push(facet);
        }
        s.push(selector);
    }

    function _removeSelectorFromFacet(DiamondStorage storage ds, address facet, bytes4 selector) private {
        bytes4[] storage s = ds.facetSelectors[facet];
        for (uint256 i = 0; i < s.length; i++) {
            if (s[i] == selector) {
                s[i] = s[s.length - 1];
                s.pop();
                if (s.length == 0) {
                    _removeFacetAddress(ds, facet);
                }
                return;
            }
        }
    }

    function _removeFacetAddress(DiamondStorage storage ds, address facet) private {
        address[] storage addrs = ds.facetAddresses;
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addrs[i] == facet) {
                addrs[i] = addrs[addrs.length - 1];
                addrs.pop();
                return;
            }
        }
    }

    function _initDiamond(address init, bytes memory calldata_) private {
        (bool success, bytes memory reason) = init.delegatecall(calldata_);
        if (!success) {
            if (reason.length > 0) {
                revert LibDiamondInitReverted(reason);
            }
            revert LibDiamondInitReverted(abi.encodePacked("Diamond init reverted"));
        }
    }

    function facetAddress(bytes4 selector) internal view returns (address) {
        return getDiamondStorage().selectorToFacet[selector];
    }

    function facets() internal view returns (IDiamondLoupe.Facet[] memory result) {
        DiamondStorage storage ds = getDiamondStorage();
        address[] memory addrs = ds.facetAddresses;
        result = new IDiamondLoupe.Facet[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            result[i] = IDiamondLoupe.Facet({facetAddress: addrs[i], functionSelectors: ds.facetSelectors[addrs[i]]});
        }
    }

    function facetFunctionSelectors(address facet) internal view returns (bytes4[] memory) {
        return getDiamondStorage().facetSelectors[facet];
    }

    function facetAddresses() internal view returns (address[] memory) {
        return getDiamondStorage().facetAddresses;
    }
}
