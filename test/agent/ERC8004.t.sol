// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC8004IdentityRegistry} from "../../src/agent/ERC8004IdentityRegistry.sol";
import {ERC8004ReputationRegistry} from "../../src/agent/ERC8004ReputationRegistry.sol";
import {ERC8004ValidationRegistry} from "../../src/agent/ERC8004ValidationRegistry.sol";
import {IERC8004IdentityRegistry} from "../../src/agent/IERC8004IdentityRegistry.sol";
import {IERC8004ReputationRegistry} from "../../src/agent/IERC8004ReputationRegistry.sol";
import {ERC1271} from "../../src/utils/cryptography/ERC1271.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MockERC1271Wallet is ERC1271 {
    address private immutable _signer;

    constructor(address signer_) {
        _signer = signer_;
    }

    function _erc1271Signer() internal view override returns (address) {
        return _signer;
    }
}

contract ERC8004Test is Test {
    ERC8004IdentityRegistry internal identity;
    ERC8004ReputationRegistry internal reputation;
    ERC8004ValidationRegistry internal validation;

    address internal owner = makeAddr("owner");
    address internal client = makeAddr("client");
    address internal validator = makeAddr("validator");
    address internal operator = makeAddr("operator");
    address internal stranger = makeAddr("stranger");

    uint256 internal walletKey = 0xBEEF;
    address internal walletSigner;

    bytes32 internal constant _AGENT_WALLET_TYPEHASH =
        keccak256("AgentWalletSet(uint256 agentId,address newWallet,address owner,uint256 deadline)");

    function setUp() public {
        walletSigner = vm.addr(walletKey);
        identity = new ERC8004IdentityRegistry();
        reputation = new ERC8004ReputationRegistry(address(identity), owner);
        validation = new ERC8004ValidationRegistry(address(identity), owner);
    }

    // --- helpers ---

    function _register(address user) internal returns (uint256 agentId) {
        vm.prank(user);
        return identity.register();
    }

    function _registerWithURI(address user, string memory uri) internal returns (uint256 agentId) {
        vm.prank(user);
        return identity.register(uri);
    }

    function _agentWalletDigest(uint256 agentId, address newWallet, address tokenOwner, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(_AGENT_WALLET_TYPEHASH, agentId, newWallet, tokenOwner, deadline));
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ERC8004IdentityRegistry")),
                keccak256(bytes("1")),
                block.chainid,
                address(identity)
            )
        );
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    function _signAgentWallet(uint256 agentId, address newWallet, address tokenOwner, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = _agentWalletDigest(agentId, newWallet, tokenOwner, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _giveFeedback(uint256 agentId, address from, int128 value, string memory tag1) internal {
        vm.prank(from);
        reputation.giveFeedback(agentId, value, 0, tag1, "", "", "", bytes32(0));
    }

    // --- Identity ---

    function test_register_bare() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC8004IdentityRegistry.Registered(0, "", owner);
        uint256 agentId = identity.register();
        assertEq(agentId, 0);
        assertEq(identity.ownerOf(agentId), owner);
        assertEq(identity.getAgentWallet(agentId), owner);
    }

    function test_register_withURI() public {
        uint256 agentId = _registerWithURI(owner, "ipfs://agent-1");
        assertEq(identity.ownerOf(agentId), owner);
        assertEq(identity.tokenURI(agentId), "ipfs://agent-1");
        assertEq(identity.getAgentWallet(agentId), owner);
    }

    function test_register_withMetadata() public {
        IERC8004IdentityRegistry.MetadataEntry[] memory entries = new IERC8004IdentityRegistry.MetadataEntry[](1);
        entries[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "skills", metadataValue: abi.encode("nlp")});

        vm.prank(owner);
        uint256 agentId = identity.register("ipfs://agent-meta", entries);
        assertEq(identity.getMetadata(agentId, "skills"), abi.encode("nlp"));
    }

    function test_register_reservedMetadataInArrayReverts() public {
        IERC8004IdentityRegistry.MetadataEntry[] memory entries = new IERC8004IdentityRegistry.MetadataEntry[](1);
        entries[0] =
            IERC8004IdentityRegistry.MetadataEntry({metadataKey: "agentWallet", metadataValue: hex"01"});

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004IdentityRegistry.ERC8004ReservedMetadataKey.selector, "agentWallet"));
        identity.register("ipfs://x", entries);
    }

    function test_setMetadata_reservedKeyReverts() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004IdentityRegistry.ERC8004ReservedMetadataKey.selector, "agentWallet"));
        identity.setMetadata(agentId, "agentWallet", hex"01");
    }

    function test_setMetadata_and_getMetadata() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        identity.setMetadata(agentId, "version", abi.encode(uint256(1)));
        assertEq(identity.getMetadata(agentId, "version"), abi.encode(uint256(1)));
    }

    function test_setMetadata_revert_notAuthorized() public {
        uint256 agentId = _register(owner);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ERC8004IdentityRegistry.ERC8004NotAuthorized.selector, agentId));
        identity.setMetadata(agentId, "version", hex"01");
    }

    function test_setAgentURI() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IERC8004IdentityRegistry.URIUpdated(agentId, "ipfs://updated", owner);
        identity.setAgentURI(agentId, "ipfs://updated");
        assertEq(identity.tokenURI(agentId), "ipfs://updated");
    }

    function test_transfer_clearsAgentWallet() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        identity.transferFrom(owner, client, agentId);
        assertEq(identity.getAgentWallet(agentId), address(0));
    }

    function test_unsetAgentWallet() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        identity.unsetAgentWallet(agentId);
        assertEq(identity.getAgentWallet(agentId), address(0));
    }

    function test_setAgentWallet_eoaSignature() public {
        uint256 agentId = _register(owner);
        uint256 deadline = block.timestamp + 60;
        bytes memory sig = _signAgentWallet(agentId, walletSigner, owner, deadline);

        vm.prank(owner);
        identity.setAgentWallet(agentId, walletSigner, deadline, sig);
        assertEq(identity.getAgentWallet(agentId), walletSigner);
    }

    function test_setAgentWallet_erc1271Wallet() public {
        MockERC1271Wallet wallet = new MockERC1271Wallet(walletSigner);
        uint256 agentId = _register(owner);
        uint256 deadline = block.timestamp + 60;
        bytes memory sig = _signAgentWallet(agentId, address(wallet), owner, deadline);

        vm.prank(owner);
        identity.setAgentWallet(agentId, address(wallet), deadline, sig);
        assertEq(identity.getAgentWallet(agentId), address(wallet));
    }

    function test_setAgentWallet_revert_invalidSignature() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(ERC8004IdentityRegistry.ERC8004InvalidWalletSignature.selector);
        identity.setAgentWallet(agentId, walletSigner, block.timestamp + 60, hex"0102");
    }

    function test_setAgentWallet_revert_expiredDeadline() public {
        vm.warp(10_000);
        uint256 agentId = _register(owner);
        uint256 deadline = 9_999;
        bytes memory sig = _signAgentWallet(agentId, walletSigner, owner, deadline);

        vm.prank(owner);
        vm.expectRevert(ERC8004IdentityRegistry.ERC8004SignatureExpired.selector);
        identity.setAgentWallet(agentId, walletSigner, deadline, sig);
    }

    function test_setAgentWallet_revert_deadlineTooFar() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(ERC8004IdentityRegistry.ERC8004DeadlineTooFar.selector);
        identity.setAgentWallet(agentId, walletSigner, block.timestamp + 6 minutes, hex"");
    }

    function test_setAgentWallet_revert_zeroWallet() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(ERC8004IdentityRegistry.ERC8004InvalidWallet.selector);
        identity.setAgentWallet(agentId, address(0), block.timestamp + 60, hex"");
    }

    function test_isAuthorizedOrOwner() public {
        uint256 agentId = _register(owner);
        assertTrue(identity.isAuthorizedOrOwner(owner, agentId));
        assertFalse(identity.isAuthorizedOrOwner(stranger, agentId));

        vm.prank(owner);
        identity.setApprovalForAll(operator, true);
        assertTrue(identity.isAuthorizedOrOwner(operator, agentId));
    }

    function testFuzz_register_incrementsAgentId(uint8 count) public {
        count = uint8(bound(count, 1, 20));
        for (uint256 i; i < count; i++) {
            vm.prank(owner);
            assertEq(identity.register(), i);
        }
    }

    // --- Reputation ---

    function test_reputation_constructor_revert_zeroIdentity() public {
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004InvalidIdentityRegistry.selector);
        new ERC8004ReputationRegistry(address(0), owner);
    }

    function test_getIdentityRegistry() public view {
        assertEq(reputation.getIdentityRegistry(), address(identity));
    }

    function test_giveFeedback_and_read() public {
        uint256 agentId = _register(owner);
        vm.prank(client);
        reputation.giveFeedback(agentId, 87, 0, "starred", "", "https://example.com", "ipfs://fb", bytes32(0));

        (int128 value, uint8 decimals, string memory tag1,, bool revoked) = reputation.readFeedback(agentId, client, 1);
        assertEq(value, 87);
        assertEq(decimals, 0);
        assertEq(tag1, "starred");
        assertFalse(revoked);
        assertEq(reputation.getLastIndex(agentId, client), 1);
    }

    function test_giveFeedback_selfFeedbackReverts() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ReputationRegistry.ERC8004SelfFeedbackNotAllowed.selector, agentId));
        reputation.giveFeedback(agentId, 1, 0, "", "", "", "", bytes32(0));
    }

    function test_giveFeedback_revert_approvedOperatorIsSelf() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        identity.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ReputationRegistry.ERC8004SelfFeedbackNotAllowed.selector, agentId));
        reputation.giveFeedback(agentId, 1, 0, "", "", "", "", bytes32(0));
    }

    function test_giveFeedback_revert_tooManyDecimals() public {
        uint256 agentId = _register(owner);
        vm.prank(client);
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004TooManyDecimals.selector);
        reputation.giveFeedback(agentId, 1, 19, "", "", "", "", bytes32(0));
    }

    function test_giveFeedback_revert_valueOutOfRange() public {
        uint256 agentId = _register(owner);
        vm.prank(client);
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004ValueOutOfRange.selector);
        reputation.giveFeedback(agentId, type(int128).max, 0, "", "", "", "", bytes32(0));
    }

    function test_revokeFeedback() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 50, "");
        vm.prank(client);
        reputation.revokeFeedback(agentId, 1);
        (,,,, bool revoked) = reputation.readFeedback(agentId, client, 1);
        assertTrue(revoked);
    }

    function test_revokeFeedback_revert_invalidIndex() public {
        uint256 agentId = _register(owner);
        vm.prank(client);
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004InvalidFeedbackIndex.selector);
        reputation.revokeFeedback(agentId, 0);
    }

    function test_revokeFeedback_revert_alreadyRevoked() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 1, "");
        vm.prank(client);
        reputation.revokeFeedback(agentId, 1);
        vm.prank(client);
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004FeedbackAlreadyRevoked.selector);
        reputation.revokeFeedback(agentId, 1);
    }

    function test_appendResponse_and_getResponseCount() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 10, "");

        vm.prank(owner);
        reputation.appendResponse(agentId, client, 1, "ipfs://response", bytes32(uint256(42)));

        assertEq(reputation.getResponseCount(agentId, client, 1, _single(owner)), 1);
    }

    function test_readAllFeedback_excludesRevokedByDefault() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 10, "a");
        _giveFeedback(agentId, client, 20, "b");
        vm.prank(client);
        reputation.revokeFeedback(agentId, 1);

        (
            address[] memory clients,
            uint64[] memory indexes,
            int128[] memory values,
            uint8[] memory valueDecimals,
            string[] memory tag1s,
            string[] memory tag2s,
            bool[] memory revoked
        ) = reputation.readAllFeedback(agentId, _singleAddr(client), "", "", false);
        valueDecimals;
        tag1s;
        tag2s;

        assertEq(clients.length, 1);
        assertEq(indexes[0], 2);
        assertEq(values[0], 20);
        assertFalse(revoked[0]);
    }

    function test_getClients() public {
        uint256 agentId = _register(owner);
        address other = makeAddr("other");
        _giveFeedback(agentId, client, 1, "");
        _giveFeedback(agentId, other, 2, "");

        address[] memory clients = reputation.getClients(agentId);
        assertEq(clients.length, 2);
    }

    function test_getSummary() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 80, "starred");

        (uint64 count, int128 summary,) = reputation.getSummary(agentId, _singleAddr(client), "starred", "");
        assertEq(count, 1);
        assertEq(summary, 80);
    }

    function test_getSummary_excludesRevoked() public {
        uint256 agentId = _register(owner);
        _giveFeedback(agentId, client, 80, "");
        vm.prank(client);
        reputation.revokeFeedback(agentId, 1);

        (uint64 count,,) = reputation.getSummary(agentId, _singleAddr(client), "", "");
        assertEq(count, 0);
    }

    function test_getSummary_revert_emptyClients() public {
        uint256 agentId = _register(owner);
        address[] memory empty;
        vm.expectRevert(ERC8004ReputationRegistry.ERC8004ClientAddressesRequired.selector);
        reputation.getSummary(agentId, empty, "", "");
    }

    function testFuzz_giveFeedback_incrementsIndex(uint8 n) public {
        n = uint8(bound(n, 1, 10));
        uint256 agentId = _register(owner);
        for (uint256 i; i < n; i++) {
            _giveFeedback(agentId, client, int128(int256(i + 1)), "");
        }
        assertEq(reputation.getLastIndex(agentId, client), n);
    }

    // --- Validation ---

    function test_validation_constructor_revert_zeroIdentity() public {
        vm.expectRevert(ERC8004ValidationRegistry.ERC8004InvalidIdentityRegistry.selector);
        new ERC8004ValidationRegistry(address(0), owner);
    }

    function test_validationRequest_and_response() public {
        uint256 agentId = _register(owner);
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

    function test_validationRequest_byApprovedOperator() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("request-op");

        vm.prank(owner);
        identity.setApprovalForAll(operator, true);
        vm.prank(operator);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);

        bytes32[] memory hashes = validation.getAgentValidations(agentId);
        assertEq(hashes.length, 1);
        assertEq(hashes[0], requestHash);
    }

    function test_validationRequest_revert_duplicateHash() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("dup");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004RequestExists.selector, requestHash));
        validation.validationRequest(validator, agentId, "ipfs://req2", requestHash);
    }

    function test_validationRequest_revert_zeroValidator() public {
        uint256 agentId = _register(owner);
        vm.prank(owner);
        vm.expectRevert(ERC8004ValidationRegistry.ERC8004InvalidValidator.selector);
        validation.validationRequest(address(0), agentId, "ipfs://req", keccak256("z"));
    }

    function test_validationRequest_revert_notAuthorized() public {
        uint256 agentId = _register(owner);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004NotAuthorized.selector, agentId));
        validation.validationRequest(validator, agentId, "ipfs://req", keccak256("unauth"));
    }

    function test_validationResponse_onlyValidator() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("request-2");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);

        vm.prank(client);
        vm.expectRevert(
            abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004NotValidator.selector, client, validator)
        );
        validation.validationResponse(requestHash, 50, "", bytes32(0), "");
    }

    function test_validationResponse_revert_unknownRequest() public {
        bytes32 missing = keccak256("missing");
        vm.prank(validator);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004UnknownRequest.selector, missing));
        validation.validationResponse(missing, 1, "", bytes32(0), "");
    }

    function test_validationResponse_revert_responseOutOfRange() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("range");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);
        vm.prank(validator);
        vm.expectRevert(abi.encodeWithSelector(ERC8004ValidationRegistry.ERC8004ResponseOutOfRange.selector, 101));
        validation.validationResponse(requestHash, 101, "", bytes32(0), "");
    }

    function test_validationResponse_multipleUpdates() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("multi");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);

        vm.prank(validator);
        validation.validationResponse(requestHash, 40, "", bytes32(0), "soft");
        vm.prank(validator);
        validation.validationResponse(requestHash, 100, "", bytes32(0), "final");

        (,, uint8 response, bytes32 responseHash, string memory tag,) = validation.getValidationStatus(requestHash);
        responseHash;
        assertEq(response, 100);
        assertEq(tag, "final");
    }

    function test_getValidatorRequests() public {
        uint256 agentId = _register(owner);
        bytes32 h1 = keccak256("v1");
        bytes32 h2 = keccak256("v2");

        vm.startPrank(owner);
        validation.validationRequest(validator, agentId, "a", h1);
        validation.validationRequest(validator, agentId, "b", h2);
        vm.stopPrank();

        bytes32[] memory requests = validation.getValidatorRequests(validator);
        assertEq(requests.length, 2);
    }

    function test_getSummary_validation() public {
        uint256 agentId = _register(owner);
        bytes32 requestHash = keccak256("request-3");

        vm.prank(owner);
        validation.validationRequest(validator, agentId, "ipfs://req", requestHash);
        vm.prank(validator);
        validation.validationResponse(requestHash, 80, "", bytes32(0), "ok");

        (uint64 count, uint8 avg) = validation.getSummary(agentId, _singleAddr(validator), "ok");
        assertEq(count, 1);
        assertEq(avg, 80);
    }

    function test_getSummary_validation_filtersTag() public {
        uint256 agentId = _register(owner);
        bytes32 h1 = keccak256("t1");
        bytes32 h2 = keccak256("t2");

        vm.startPrank(owner);
        validation.validationRequest(validator, agentId, "a", h1);
        validation.validationRequest(validator, agentId, "b", h2);
        vm.stopPrank();

        vm.startPrank(validator);
        validation.validationResponse(h1, 60, "", bytes32(0), "keep");
        validation.validationResponse(h2, 100, "", bytes32(0), "drop");
        vm.stopPrank();

        (uint64 count, uint8 avg) = validation.getSummary(agentId, _singleAddr(validator), "keep");
        assertEq(count, 1);
        assertEq(avg, 60);
    }

    function _single(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }

    function _singleAddr(address addr) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = addr;
    }
}
