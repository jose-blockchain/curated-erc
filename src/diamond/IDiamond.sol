// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamond
 * @dev Core diamond interface (EIP-2535). Defines FacetCut and DiamondCut event.
 * See https://eips.ethereum.org/EIPS/eip-2535
 */
interface IDiamond {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] diamondCut, address init, bytes calldata_);
}
