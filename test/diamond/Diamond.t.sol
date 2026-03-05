// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../../src/diamond/Diamond.sol";
import {IDiamond} from "../../src/diamond/IDiamond.sol";
import {IDiamondCut} from "../../src/diamond/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/diamond/IDiamondLoupe.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {TestFacet} from "./TestFacet.sol";
import {TestFacet2} from "./TestFacet2.sol";

contract DiamondTest is Test {
    Diamond internal diamond;
    TestFacet internal facet;
    TestFacet2 internal facet2;

    address internal owner;
    address internal stranger;

    function setUp() public {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");
        facet = new TestFacet();
        facet2 = new TestFacet2();

        IDiamond.FacetCut[] memory empty;
        vm.prank(owner);
        diamond = new Diamond(owner, empty);
    }

    function _addTestFacet() internal {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TestFacet.setValue.selector;
        selectors[1] = TestFacet.getValue.selector;
        selectors[2] = TestFacet.add.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    // --- Loupe (no facets except immutable) ---

    function test_facets_includesImmutableFacet() public view {
        IDiamondLoupe.Facet[] memory f = IDiamondLoupe(address(diamond)).facets();
        assertGt(f.length, 0);
        bool foundDiamond;
        for (uint256 i = 0; i < f.length; i++) {
            if (f[i].facetAddress == address(diamond)) {
                foundDiamond = true;
                assertEq(f[i].functionSelectors.length, 5);
                break;
            }
        }
        assertTrue(foundDiamond);
    }

    function test_facetAddress_loupeSelectorsReturnDiamond() public view {
        assertEq(IDiamondLoupe(address(diamond)).facetAddress(IDiamondLoupe.facets.selector), address(diamond));
        assertEq(IDiamondLoupe(address(diamond)).facetAddress(IDiamondCut.diamondCut.selector), address(diamond));
    }

    function test_facetAddress_unknownSelectorReturnsZero() public view {
        assertEq(IDiamondLoupe(address(diamond)).facetAddress(TestFacet.setValue.selector), address(0));
    }

    function test_facetAddresses_includesDiamond() public view {
        address[] memory addrs = IDiamondLoupe(address(diamond)).facetAddresses();
        assertEq(addrs[addrs.length - 1], address(diamond));
    }

    function test_facetFunctionSelectors_diamond() public view {
        bytes4[] memory s = IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(diamond));
        assertEq(s.length, 5);
    }

    // --- Add facet and delegatecall ---

    function test_diamondCut_addThenCall() public {
        _addTestFacet();
        TestFacet(address(diamond)).setValue(42);
        assertEq(TestFacet(address(diamond)).getValue(), 42);
    }

    function test_diamondCut_add_pureFunction() public {
        _addTestFacet();
        assertEq(TestFacet(address(diamond)).add(3, 7), 10);
    }

    function test_diamondCut_add_loupeReturnsFacet() public {
        _addTestFacet();
        address f = IDiamondLoupe(address(diamond)).facetAddress(TestFacet.setValue.selector);
        assertEq(f, address(facet));
        bytes4[] memory s = IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(facet));
        assertEq(s.length, 3);
    }

    function test_constructor_revert_zeroOwner() public {
        IDiamond.FacetCut[] memory empty;
        vm.expectRevert(LibDiamond.LibDiamondInvalidOwner.selector);
        new Diamond(address(0), empty);
    }

    function test_diamondCut_revert_emptySelectors() public {
        bytes4[] memory selectors = new bytes4[](0);
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(owner);
        vm.expectRevert(LibDiamond.LibDiamondEmptySelectors.selector);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_revert_facetHasNoCode() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.setValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: stranger, action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamondFacetHasNoCode.selector, stranger));
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_revert_initHasNoCode() public {
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](0);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamondInitHasNoCode.selector, stranger));
        IDiamondCut(address(diamond)).diamondCut(cut, stranger, "");
    }

    function test_constructor_revert_immutableRemovalInInitialCut() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondLoupe.facets.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(0), action: IDiamond.FacetCutAction.Remove, functionSelectors: selectors
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamondImmutableSelector.selector, IDiamondLoupe.facets.selector)
        );
        new Diamond(owner, cut);
    }

    function test_diamondCut_revert_onlyOwner() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.setValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(stranger);
        vm.expectRevert(LibDiamond.LibDiamondOnlyOwner.selector);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_revert_addDuplicateSelector() public {
        _addTestFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.setValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet2), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamondSelectorAlreadyExists.selector, TestFacet.setValue.selector)
        );
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    // --- Replace ---

    function test_diamondCut_replace() public {
        _addTestFacet();
        TestFacet(address(diamond)).setValue(100);
        assertEq(TestFacet(address(diamond)).getValue(), 100);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = TestFacet.setValue.selector;
        selectors[1] = TestFacet.getValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet2), action: IDiamond.FacetCutAction.Replace, functionSelectors: selectors
        });
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        assertEq(IDiamondLoupe(address(diamond)).facetAddress(TestFacet.setValue.selector), address(facet2));
        TestFacet2(address(diamond)).setValue(200);
        assertEq(TestFacet2(address(diamond)).getValue(), 200);
    }

    function test_diamondCut_replace_revert_selectorNotFound() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.setValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet2), action: IDiamond.FacetCutAction.Replace, functionSelectors: selectors
        });
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamondSelectorNotFound.selector, TestFacet.setValue.selector)
        );
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    // --- Remove ---

    function test_diamondCut_remove() public {
        _addTestFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TestFacet.add.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(0), action: IDiamond.FacetCutAction.Remove, functionSelectors: selectors
        });
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        assertEq(IDiamondLoupe(address(diamond)).facetAddress(TestFacet.add.selector), address(0));
        vm.expectRevert(abi.encodeWithSelector(LibDiamond.LibDiamondSelectorNotFound.selector, TestFacet.add.selector));
        TestFacet(address(diamond)).add(1, 2);
    }

    function test_diamondCut_remove_revert_immutable() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibDiamond.LibDiamondImmutableSelector.selector, IDiamondLoupe.facets.selector)
        );
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondLoupe.facets.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(0), action: IDiamond.FacetCutAction.Remove, functionSelectors: selectors
        });
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    // --- Deploy with initial facets ---

    function test_constructor_withInitialFacets() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = TestFacet.setValue.selector;
        selectors[1] = TestFacet.getValue.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        vm.prank(owner);
        Diamond d = new Diamond(owner, cut);
        TestFacet(address(d)).setValue(99);
        assertEq(TestFacet(address(d)).getValue(), 99);
    }

    // --- Init ---

    function test_diamondCut_withInit() public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TestFacet.setValue.selector;
        selectors[1] = TestFacet.getValue.selector;
        selectors[2] = TestFacet.init.selector;
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut({
            facetAddress: address(facet), action: IDiamond.FacetCutAction.Add, functionSelectors: selectors
        });
        bytes memory initCalldata = abi.encodeWithSelector(TestFacet.init.selector, 123);
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(facet), initCalldata);
        assertEq(TestFacet(address(diamond)).getValue(), 123);
    }

    // --- Receive ---

    function test_receive_acceptsEth() public {
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        (bool ok,) = address(diamond).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(diamond).balance, 1 ether);
    }

    // --- Fuzz ---

    function testFuzz_setValue_getValue(uint256 v) public {
        _addTestFacet();
        TestFacet(address(diamond)).setValue(v);
        assertEq(TestFacet(address(diamond)).getValue(), v);
    }

    function testFuzz_add(uint256 a, uint256 b) public {
        a = bound(a, 0, type(uint256).max / 2);
        b = bound(b, 0, type(uint256).max / 2);
        _addTestFacet();
        assertEq(TestFacet(address(diamond)).add(a, b), a + b);
    }
}
