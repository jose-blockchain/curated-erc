// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC8004IdentityRegistry} from "../../src/agent/ERC8004IdentityRegistry.sol";
import {ERC8004ReputationRegistry} from "../../src/agent/ERC8004ReputationRegistry.sol";
import {ERC8004ValidationRegistry} from "../../src/agent/ERC8004ValidationRegistry.sol";
import {IERC8004IdentityRegistry} from "../../src/agent/IERC8004IdentityRegistry.sol";
import {IERC8004ReputationRegistry} from "../../src/agent/IERC8004ReputationRegistry.sol";
import {IERC8004ValidationRegistry} from "../../src/agent/IERC8004ValidationRegistry.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ERC8004Test is Test {
    ERC8004IdentityRegistry internal identity;
    ERC8004ReputationRegistry internal reputation;
    ERC8004ValidationRegistry internal validation;

    address internal owner = makeAddr("owner");
    address internal client = makeAddr("client");
    address internal validator = makeAddr("validator");
    address internal newWallet = makeAddr("newWallet");

    uint256 internal walletKey = 0xBEEF;
    address internal walletSigner;

    function setUp() public {
        walletSigner = vm.addr(walletKey);
        identity = new ERC8004IdentityRegistry();
        reputation = new ERC8004ReputationRegistry(address(identity), owner);
        validation = new ERC8004ValidationRegistry(address(identity), owner);
    }

    // --- Identity ---

    function test_register_withURI() public {
        vm.prank(owner);
        uint256 agentId = identity.register("ipfs://agent-1");
        assertEq(identity.ownerOf(agentId), owner);
        assertEq(identity.tokenURI(agentId), "ipfs://agent-1");
        assertEq(identity.getAgentWallet(agentId), owner);
    }

    function test_setMetadata_reservedKeyReverts() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004IdentityRegistry.ERC8004ReservedMetadataKey.selector, "agentWallet"));
        identity.setMetadata(agentId, "agentWallet", hex"01");
    }

    function test_transfer_clearsAgentWallet() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        vm.prank(owner);
        identity.transferFrom(owner, client, agentId);
        assertEq(identity.getAgentWallet(agentId), address(0));
    }

    function test_setAgentWallet_eoaSignature() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        uint256 deadline = block.timestamp + 60;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("AgentWalletSet(uint256 agentId,address newWallet,address owner,uint256 deadline)"),
                agentId,
                walletSigner,
                owner,
                deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ERC8004IdentityRegistry")),
                keccak256(bytes("1")),
                block.chainid,
                address(identity)
            )
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(owner);
        identity.setAgentWallet(agentId, walletSigner, deadline, sig);
        assertEq(identity.getAgentWallet(agentId), walletSigner);
    }

    // --- Reputation ---

    function test_giveFeedback_and_read() public {
        vm.prank(owner);
        uint256 agentId = identity.register();

        vm.prank(client);
        reputation.giveFeedback(agentId, 87, 0, "starred", "", "https://example.com", "ipfs://fb", bytes32(0));

        (int128 value, uint8 decimals, string memory tag1,, bool revoked) = reputation.readFeedback(agentId, client, 1);
        assertEq(value, 87);
        assertEq(decimals, 0);
        assertEq(tag1, "starred");
        assertFalse(revoked);
    }

    function test_giveFeedback_selfFeedbackReverts() public {
        vm.prank(owner);
        uint256 agentId = identity.register();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ReputationRegistry.ERC8004SelfFeedbackNotAllowed.selector, agentId));
        reputation.giveFeedback(agentId, 1, 0, "", "", "", "", bytes32(0));
    }

    function test_revokeFeedback() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        vm.prank(client);
        reputation.giveFeedback(agentId, 50, 0, "", "", "", "", bytes32(0));
        vm.prank(client);
        reputation.revokeFeedback(agentId, 1);
        (,,,, bool revoked) = reputation.readFeedback(agentId, client, 1);
        assertTrue(revoked);
    }

    function test_getSummary() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        address[] memory clients = new address[](1);
        clients[0] = client;

        vm.prank(client);
        reputation.giveFeedback(agentId, 80, 0, "starred", "", "", "", bytes32(0));

        (uint64 count, int128 summary,) = reputation.getSummary(agentId, clients, "starred", "");
        assertEq(count, 1);
        assertEq(summary, 80);
    }

    // --- Validation ---

    function test_validationRequest_and_response() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        bytes32 requestHash = keccak256("request-1");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);

        vm.prank(validator);
        validation.validationResponse(requestHash, 100, "ipfs://res", bytes32(uint256(1)), "final");

        (address v, uint256 a, uint8 response,,, uint256 lastUpdate) = validation.getValidationStatus(requestHash);
        assertEq(v, validator);
        assertEq(a, agentId);
        assertEq(response, 100);
        assertGt(lastUpdate, 0);
    }

    function test_validationResponse_onlyValidator() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        bytes32 requestHash = keccak256("request-2");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004NotValidator.selector, client, validator)
        );
        validation.validationResponse(requestHash, 50, "", bytes32(0), "");
    }

    function test_getSummary_validation() public {
        vm.prank(owner);
        uint256 agentId = identity.register();
        bytes32 requestHash = keccak256("request-3");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);
        vm.prank(validator);
        validation.validationResponse(requestHash, 80, "", bytes32(0), "");

        address[] memory validators = new address[](1);
        validators[0] = validator;
        (uint64 count, uint8 avg) = validation.getSummary(agentId, validators, "");
        assertEq(count, 1);
        assertEq(avg, 80);
    }
}
