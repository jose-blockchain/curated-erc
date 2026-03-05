// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamond} from "./IDiamond.sol";
import {IDiamondCut} from "./IDiamondCut.sol";
import {IDiamondLoupe} from "./IDiamondLoupe.sol";
import {LibDiamond} from "./LibDiamond.sol";

/**
 * @title Diamond
 * @dev EIP-2535 Diamond: multi-facet proxy with upgrade (diamondCut) and loupe introspection.
 * See https://eips.ethereum.org/EIPS/eip-2535
 *
 * Owner is set to msg.sender in constructor. Only owner can call diamondCut.
 * Loupe and diamondCut are implemented in the diamond (immutable); all other functions
 * are delegated to facets via fallback.
 */
contract Diamond is IDiamond, IDiamondCut, IDiamondLoupe {
    /// @dev Immutable selectors (loupe + diamondCut). Not stored in selectorToFacet to avoid fallback delegatecall to self.
    bytes4 private constant LOUPE_FACETS = IDiamondLoupe.facets.selector;
    bytes4 private constant LOUPE_FACET_FUNCTION_SELECTORS = IDiamondLoupe.facetFunctionSelectors.selector;
    bytes4 private constant LOUPE_FACET_ADDRESSES = IDiamondLoupe.facetAddresses.selector;
    bytes4 private constant LOUPE_FACET_ADDRESS = IDiamondLoupe.facetAddress.selector;
    bytes4 private constant CUT_DIAMOND_CUT = IDiamondCut.diamondCut.selector;

    constructor(address _contractOwner, IDiamond.FacetCut[] memory _diamondCut) {
        LibDiamond.setContractOwner(_contractOwner);

        if (_diamondCut.length > 0) {
            LibDiamond.diamondCut(_diamondCut, address(0), "");
            emit DiamondCut(_diamondCut, address(0), "");
        }

        // Emit immutable functions as added (EIP-2535: "immutable functions must be emitted in DiamondCut event")
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = LOUPE_FACETS;
        loupeSelectors[1] = LOUPE_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = LOUPE_FACET_ADDRESSES;
        loupeSelectors[3] = LOUPE_FACET_ADDRESS;
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = CUT_DIAMOND_CUT;
        IDiamond.FacetCut[] memory immutableCut = new IDiamond.FacetCut[](2);
        immutableCut[0] = IDiamond.FacetCut({
            facetAddress: address(this),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        immutableCut[1] = IDiamond.FacetCut({
            facetAddress: address(this),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });
        emit DiamondCut(immutableCut, address(0), "");
    }

    receive() external payable {}

    fallback() external payable {
        address facet = _facetForSelector(msg.sig);
        if (facet == address(0)) {
            revert LibDiamond.LibDiamondSelectorNotFound(msg.sig);
        }
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @inheritdoc IDiamondCut
    function diamondCut(
        IDiamond.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();
        _rejectImmutableRemoval(_diamondCut);
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
        emit DiamondCut(_diamondCut, _init, _calldata);
    }

    function _rejectImmutableRemoval(IDiamond.FacetCut[] calldata _diamondCut) private pure {
        for (uint256 i = 0; i < _diamondCut.length; i++) {
            if (_diamondCut[i].action != IDiamond.FacetCutAction.Remove) continue;
            bytes4[] calldata s = _diamondCut[i].functionSelectors;
            for (uint256 j = 0; j < s.length; j++) {
                if (
                    s[j] == LOUPE_FACETS || s[j] == LOUPE_FACET_FUNCTION_SELECTORS
                        || s[j] == LOUPE_FACET_ADDRESSES || s[j] == LOUPE_FACET_ADDRESS
                        || s[j] == CUT_DIAMOND_CUT
                ) {
                    revert LibDiamond.LibDiamondImmutableSelector(s[j]);
                }
            }
        }
    }

    /// @inheritdoc IDiamondLoupe
    function facets() external view override returns (Facet[] memory) {
        Facet[] memory fromStorage = LibDiamond.facets();
        bytes4[] memory immutableSelectors = new bytes4[](5);
        immutableSelectors[0] = LOUPE_FACETS;
        immutableSelectors[1] = LOUPE_FACET_FUNCTION_SELECTORS;
        immutableSelectors[2] = LOUPE_FACET_ADDRESSES;
        immutableSelectors[3] = LOUPE_FACET_ADDRESS;
        immutableSelectors[4] = CUT_DIAMOND_CUT;
        Facet[] memory result = new Facet[](fromStorage.length + 1);
        for (uint256 i = 0; i < fromStorage.length; i++) {
            result[i] = fromStorage[i];
        }
        result[fromStorage.length] = Facet({ facetAddress: address(this), functionSelectors: immutableSelectors });
        return result;
    }

    /// @inheritdoc IDiamondLoupe
    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory) {
        if (_facet == address(this)) {
            bytes4[] memory s = new bytes4[](5);
            s[0] = LOUPE_FACETS;
            s[1] = LOUPE_FACET_FUNCTION_SELECTORS;
            s[2] = LOUPE_FACET_ADDRESSES;
            s[3] = LOUPE_FACET_ADDRESS;
            s[4] = CUT_DIAMOND_CUT;
            return s;
        }
        return LibDiamond.facetFunctionSelectors(_facet);
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddresses() external view override returns (address[] memory) {
        address[] memory fromStorage = LibDiamond.facetAddresses();
        // Include address(this) if not already present (immutable facet)
        for (uint256 i = 0; i < fromStorage.length; i++) {
            if (fromStorage[i] == address(this)) return fromStorage;
        }
        address[] memory result = new address[](fromStorage.length + 1);
        for (uint256 i = 0; i < fromStorage.length; i++) {
            result[i] = fromStorage[i];
        }
        result[fromStorage.length] = address(this);
        return result;
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddress(bytes4 _functionSelector) external view override returns (address) {
        return _facetForSelector(_functionSelector);
    }

    /// @dev Returns facet for selector; address(this) for immutable selectors, else from storage.
    function _facetForSelector(bytes4 selector) internal view returns (address) {
        if (
            selector == LOUPE_FACETS || selector == LOUPE_FACET_FUNCTION_SELECTORS
                || selector == LOUPE_FACET_ADDRESSES || selector == LOUPE_FACET_ADDRESS
                || selector == CUT_DIAMOND_CUT
        ) {
            return address(this);
        }
        return LibDiamond.facetAddress(selector);
    }
}
