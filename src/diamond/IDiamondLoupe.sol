// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamondLoupe
 * @dev Introspection interface (EIP-2535). Inspect facets and function selectors.
 * See https://eips.ethereum.org/EIPS/eip-2535
 */
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Returns all facets and their selectors.
     */
    function facets() external view returns (Facet[] memory facets_);

    /**
     * @notice Returns the function selectors for a facet.
     * @param facet The facet address.
     */
    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /**
     * @notice Returns all facet addresses used by the diamond.
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /**
     * @notice Returns the facet that supports the given selector.
     * @param functionSelector The function selector.
     * @return facetAddress_ The facet address, or address(0) if not found.
     */
    function facetAddress(bytes4 functionSelector) external view returns (address facetAddress_);
}
