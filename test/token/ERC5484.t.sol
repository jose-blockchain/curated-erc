// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC5484} from "../../src/token/ERC5484/ERC5484.sol";
import {IERC5484} from "../../src/token/ERC5484/IERC5484.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {StorageSlot7201} from "../../src/utils/StorageSlot7201.sol";

contract MockERC5484 is ERC5484 {
    constructor() ERC721("ConsensualSBT", "CSBT") {}

    function issue(address to, uint256 tokenId, IERC5484.BurnAuth auth) external {
        _issue(to, tokenId, auth);
    }

    function burn(uint256 tokenId) external {
        _burnWithAuth(tokenId);
    }
}

contract ERC5484Test is Test {
    MockERC5484 internal sbt;

    address internal issuer = makeAddr("issuer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        sbt = new MockERC5484();
    }

    // --- Verify storage slot ---

    function test_storageSlot() public pure {
        bytes32 expected = StorageSlot7201.erc7201Slot("curatedcontracts.storage.ERC5484");
        assertEq(expected, 0xf52fe779b91964094995287fb83d407644566a5d0f43000d4b3946580d550200);
    }

    // --- ERC165 ---

    function test_supportsInterface() public view {
        assertTrue(sbt.supportsInterface(type(IERC5484).interfaceId));
    }

    // --- Issue ---

    function test_issue_emitsEvent() public {
        vm.prank(issuer);
        vm.expectEmit(true, true, true, true);
        emit IERC5484.Issued(issuer, alice, 1, IERC5484.BurnAuth.Both);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        assertEq(sbt.ownerOf(1), alice);
        assertEq(sbt.issuerOf(1), issuer);
        assertEq(uint8(sbt.burnAuth(1)), uint8(IERC5484.BurnAuth.Both));
    }

    function test_issue_allBurnAuthTypes() public {
        vm.startPrank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.IssuerOnly);
        sbt.issue(alice, 2, IERC5484.BurnAuth.OwnerOnly);
        sbt.issue(alice, 3, IERC5484.BurnAuth.Both);
        sbt.issue(alice, 4, IERC5484.BurnAuth.Neither);
        vm.stopPrank();

        assertEq(uint8(sbt.burnAuth(1)), uint8(IERC5484.BurnAuth.IssuerOnly));
        assertEq(uint8(sbt.burnAuth(2)), uint8(IERC5484.BurnAuth.OwnerOnly));
        assertEq(uint8(sbt.burnAuth(3)), uint8(IERC5484.BurnAuth.Both));
        assertEq(uint8(sbt.burnAuth(4)), uint8(IERC5484.BurnAuth.Neither));
    }

    // --- Transfer blocked ---

    function test_transfer_revert() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(alice);
        vm.expectRevert(ERC5484.ERC5484TransferDisabled.selector);
        sbt.transferFrom(alice, bob, 1);
    }

    function test_safeTransfer_revert() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(alice);
        vm.expectRevert(ERC5484.ERC5484TransferDisabled.selector);
        sbt.safeTransferFrom(alice, bob, 1);
    }

    // --- Burn: IssuerOnly ---

    function test_burn_issuerOnly_byIssuer() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.IssuerOnly);

        vm.prank(issuer);
        sbt.burn(1);

        vm.expectRevert();
        sbt.ownerOf(1);
    }

    function test_burn_issuerOnly_revert_byOwner() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.IssuerOnly);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, 1));
        sbt.burn(1);
    }

    // --- Burn: OwnerOnly ---

    function test_burn_ownerOnly_byOwner() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.OwnerOnly);

        vm.prank(alice);
        sbt.burn(1);

        vm.expectRevert();
        sbt.ownerOf(1);
    }

    function test_burn_ownerOnly_revert_byIssuer() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.OwnerOnly);

        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, 1));
        sbt.burn(1);
    }

    // --- Burn: Both ---

    function test_burn_both_byIssuer() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(issuer);
        sbt.burn(1);
    }

    function test_burn_both_byOwner() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(alice);
        sbt.burn(1);
    }

    function test_burn_both_revert_byThirdParty() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, 1));
        sbt.burn(1);
    }

    // --- Burn: Neither ---

    function test_burn_neither_revert_byAnyone() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Neither);

        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, 1));
        sbt.burn(1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, 1));
        sbt.burn(1);
    }

    // --- Fuzz ---

    function testFuzz_issue(address to, uint256 tokenId, uint8 authRaw) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        authRaw = uint8(bound(authRaw, 0, 3));
        IERC5484.BurnAuth auth = IERC5484.BurnAuth(authRaw);

        vm.prank(issuer);
        sbt.issue(to, tokenId, auth);

        assertEq(sbt.ownerOf(tokenId), to);
        assertEq(uint8(sbt.burnAuth(tokenId)), authRaw);
        assertEq(sbt.issuerOf(tokenId), issuer);
    }

    // --- Token data cleared after burn ---

    function test_burn_clearsTokenData() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.IssuerOnly);

        vm.prank(issuer);
        sbt.burn(1);

        // Re-issue same tokenId — should have fresh data
        vm.prank(bob);
        sbt.issue(alice, 1, IERC5484.BurnAuth.OwnerOnly);
        assertEq(sbt.issuerOf(1), bob);
        assertEq(uint8(sbt.burnAuth(1)), uint8(IERC5484.BurnAuth.OwnerOnly));
    }

    // --- Approved operator cannot transfer ---

    function test_approvedOperator_cannotTransfer() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(alice);
        sbt.approve(bob, 1);

        vm.prank(bob);
        vm.expectRevert(ERC5484.ERC5484TransferDisabled.selector);
        sbt.transferFrom(alice, bob, 1);
    }

    // --- SetApprovalForAll does not bypass soulbound ---

    function test_operatorForAll_cannotTransfer() public {
        vm.prank(issuer);
        sbt.issue(alice, 1, IERC5484.BurnAuth.Both);

        vm.prank(alice);
        sbt.setApprovalForAll(bob, true);

        vm.prank(bob);
        vm.expectRevert(ERC5484.ERC5484TransferDisabled.selector);
        sbt.transferFrom(alice, bob, 1);
    }

    // --- burnAuth/issuerOf revert for nonexistent token ---

    function test_burnAuth_revert_nonexistent() public {
        vm.expectRevert();
        sbt.burnAuth(999);
    }

    function test_issuerOf_revert_nonexistent() public {
        vm.expectRevert();
        sbt.issuerOf(999);
    }

    // --- Fuzz burn authorization ---

    function testFuzz_burnWithAuth_issuerOnly(uint256 tokenId) public {
        vm.assume(tokenId > 10);
        vm.prank(issuer);
        sbt.issue(alice, tokenId, IERC5484.BurnAuth.IssuerOnly);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, tokenId));
        sbt.burn(tokenId);

        vm.prank(issuer);
        sbt.burn(tokenId);
        vm.expectRevert();
        sbt.ownerOf(tokenId);
    }

    function testFuzz_burnWithAuth_ownerOnly(uint256 tokenId) public {
        vm.assume(tokenId > 10);
        vm.prank(issuer);
        sbt.issue(alice, tokenId, IERC5484.BurnAuth.OwnerOnly);

        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSelector(ERC5484.ERC5484BurnUnauthorized.selector, tokenId));
        sbt.burn(tokenId);

        vm.prank(alice);
        sbt.burn(tokenId);
        vm.expectRevert();
        sbt.ownerOf(tokenId);
    }
}
