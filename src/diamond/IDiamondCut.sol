// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamond} from "./IDiamond.sol";

/**
 * @title IDiamondCut
 * @dev Diamond upgrade interface (EIP-2535). Add/replace/remove functions and optionally run init.
 * See https://eips.ethereum.org/EIPS/eip-2535
 */
interface IDiamondCut is IDiamond {
    /**
     * @notice Add/replace/remove functions and optionally execute a setup function.
     * @param diamondCut Array of facet cuts.
     * @param init Address of contract to run after cuts (use address(0) to skip).
     * @param calldata_ Calldata for delegatecall to init.
     */
    function diamondCut(FacetCut[] calldata diamondCut, address init, bytes calldata calldata_) external;
}
