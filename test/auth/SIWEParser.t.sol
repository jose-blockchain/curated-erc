// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SIWE} from "../../src/auth/SIWE.sol";
import {SIWEParser} from "../../src/auth/SIWEParser.sol";

contract SIWEParserTest is Test {
    uint256 internal constant _PRIVATE_KEY = 0xA11CE;
    address internal _signer;
    SIWEParser internal _parser;

    function setUp() public {
        _signer = vm.addr(_PRIVATE_KEY);
        _parser = new SIWEParser();
    }

    function _baseMessage() internal view returns (string memory) {
        return _siwe(
            "service.invalid",
            vm.toString(_signer),
            "I accept the ServiceOrg Terms of Service: https://service.invalid/tos",
            "https://service.invalid/login",
            "1",
            "1",
            "32891757",
            "2021-09-30T16:25:24.000Z"
        );
    }

    function _siwe(
        string memory domain,
        string memory addressLine,
        string memory statement,
        string memory uri,
        string memory version,
        string memory chainId,
        string memory nonce,
        string memory issuedAt
    ) internal pure returns (string memory) {
        string memory stmtBlock = bytes(statement).length == 0 ? "" : string.concat(statement, "\n", "\n");
        return string.concat(
            domain,
            " wants you to sign in with your Ethereum account:\n",
            addressLine,
            "\n\n",
            stmtBlock,
            "URI: ",
            uri,
            "\nVersion: ",
            version,
            "\nChain ID: ",
            chainId,
            "\nNonce: ",
            nonce,
            "\nIssued At: ",
            issuedAt
        );
    }

    function _hasLf(string memory value) internal pure returns (bool) {
        bytes memory raw = bytes(value);
        for (uint256 i; i < raw.length; i++) {
            if (raw[i] == 0x0a) return true;
        }
        return false;
    }

    function test_parse_requiredFields() public view {
        SIWE.Message memory parsed = SIWE.parse(_baseMessage());
        assertEq(parsed.domain, "service.invalid");
        assertEq(parsed.user, _signer);
        assertEq(parsed.statement, "I accept the ServiceOrg Terms of Service: https://service.invalid/tos");
        assertEq(parsed.uri, "https://service.invalid/login");
        assertEq(parsed.version, 1);
        assertEq(parsed.chainId, 1);
        assertEq(parsed.nonce, "32891757");
        assertEq(parsed.issuedAt, "2021-09-30T16:25:24.000Z");
        assertEq(parsed.expirationTime, "");
        assertEq(parsed.notBefore, "");
        assertEq(parsed.requestId, "");
    }

    function test_parserContract_matchesLibrary() public view {
        SIWE.Message memory viaContract = _parser.parse(_baseMessage());
        SIWE.Message memory viaLib = SIWE.parse(_baseMessage());
        assertEq(viaContract.domain, viaLib.domain);
        assertEq(viaContract.user, viaLib.user);
        assertEq(viaContract.statement, viaLib.statement);
        assertEq(viaContract.uri, viaLib.uri);
        assertEq(viaContract.version, viaLib.version);
        assertEq(viaContract.chainId, viaLib.chainId);
        assertEq(viaContract.nonce, viaLib.nonce);
        assertEq(viaContract.issuedAt, viaLib.issuedAt);
        assertEq(viaContract.expirationTime, viaLib.expirationTime);
        assertEq(viaContract.notBefore, viaLib.notBefore);
        assertEq(viaContract.requestId, viaLib.requestId);
    }

    function test_parse_matchesParseAddress() public view {
        string memory message = _baseMessage();
        assertEq(SIWE.parse(message).user, SIWE.parseAddress(message));
    }

    function test_parse_optionalTimeAndRequestId() public view {
        string memory message = string.concat(
            _baseMessage(),
            "\nExpiration Time: 2021-10-01T00:00:00.000Z",
            "\nNot Before: 2021-09-30T00:00:00.000Z",
            "\nRequest ID: req-9"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.expirationTime, "2021-10-01T00:00:00.000Z");
        assertEq(parsed.notBefore, "2021-09-30T00:00:00.000Z");
        assertEq(parsed.requestId, "req-9");
    }

    function test_parse_noStatement() public view {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "\n",
            "URI: https://example.com\n",
            "Version: 1\n",
            "Chain ID: 10\n",
            "Nonce: n1\n",
            "Issued At: 2024-01-01T00:00:00Z"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.domain, "example.com");
        assertEq(parsed.statement, "");
        assertEq(parsed.chainId, 10);
    }

    function test_parse_eip4361ExampleWithResources() public pure {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2\n",
            "\n",
            "I accept the ExampleOrg Terms of Service: https://example.com/tos\n",
            "\n",
            "URI: https://example.com/login\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: 32891756\n",
            "Issued At: 2021-09-30T16:25:24Z\n",
            "Resources:\n",
            "- ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/\n",
            "- https://example.com/my-web2-claim.json"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.domain, "example.com");
        assertEq(parsed.user, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(parsed.statement, "I accept the ExampleOrg Terms of Service: https://example.com/tos");
        assertEq(parsed.uri, "https://example.com/login");
        assertEq(parsed.nonce, "32891756");
        assertEq(parsed.issuedAt, "2021-09-30T16:25:24Z");
        assertEq(parsed.requestId, "");
    }

    function test_parse_uppercaseAddress() public pure {
        string memory message = _siwe(
            "example.com",
            "0xC02AAA39B223FE8D0A0E5C4F27EAD9083C756CC2",
            "",
            "https://example.com",
            "1",
            "1",
            "n1",
            "2024-01-01T00:00:00Z"
        );
        assertEq(SIWE.parse(message).user, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    function test_parse_domainWithPort() public view {
        string memory message = _siwe(
            "localhost:8545",
            vm.toString(_signer),
            "",
            "http://localhost:8545",
            "1",
            "31337",
            "localnonce",
            "2024-01-01T00:00:00Z"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.domain, "localhost:8545");
        assertEq(parsed.chainId, 31337);
    }

    function test_parse_chainIdZero() public view {
        string memory message = _siwe(
            "example.com", vm.toString(_signer), "", "https://example.com", "1", "0", "n1", "2024-01-01T00:00:00Z"
        );
        assertEq(SIWE.parse(message).chainId, 0);
    }

    function test_parse_noBlankLineBeforeUri() public view {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "URI: https://example.com\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: n1\n",
            "Issued At: 2024-01-01T00:00:00Z"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.statement, "");
        assertEq(parsed.uri, "https://example.com");
    }

    function test_parse_revert_empty() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse("");
    }

    function test_parse_revert_missingHeader() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse("not a siwe message");
    }

    function test_parse_revert_emptyDomain() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse(
            string.concat(
                " wants you to sign in with your Ethereum account:\n",
                vm.toString(_signer),
                "\n\nURI: https://example.com\nVersion: 1\nChain ID: 1\nNonce: n\nIssued At: 2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_newlineInDomain() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse(
            string.concat(
                "evil.com\nexample.com wants you to sign in with your Ethereum account:\n",
                vm.toString(_signer),
                "\n\nURI: https://example.com\nVersion: 1\nChain ID: 1\nNonce: n\nIssued At: 2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_badAddress() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            "not-an-address\n",
            "\n",
            "URI: https://example.com\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: n\n",
            "Issued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_shortAddress() public {
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(
            _siwe("example.com", "0x1234", "", "https://example.com", "1", "1", "n", "2024-01-01T00:00:00Z")
        );
    }

    function test_parse_revert_longAddress() public {
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(
            _siwe(
                "example.com",
                "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2ff",
                "",
                "https://example.com",
                "1",
                "1",
                "n",
                "2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_invalidHexAddress() public {
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(
            _siwe(
                "example.com",
                "0xGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
                "",
                "https://example.com",
                "1",
                "1",
                "n",
                "2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_addressMissing0x() public {
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(
            _siwe(
                "example.com",
                "C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                "",
                "https://example.com",
                "1",
                "1",
                "n",
                "2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_addressMissingNewline() public {
        vm.expectRevert(SIWE.SIWEInvalidAddressLine.selector);
        this.exposedParse(
            string.concat("example.com wants you to sign in with your Ethereum account:\n", vm.toString(_signer))
        );
    }

    function test_parse_revert_missingUri() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: n\n",
            "Issued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_emptyUri() public {
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(_siwe("example.com", vm.toString(_signer), "", "", "1", "1", "n", "2024-01-01T00:00:00Z"));
    }

    function test_parse_revert_missingNonce() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n\nURI: https://example.com\nVersion: 1\nChain ID: 1\nIssued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_emptyNonce() public {
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(
            _siwe("example.com", vm.toString(_signer), "", "https://example.com", "1", "1", "", "2024-01-01T00:00:00Z")
        );
    }

    function test_parse_revert_missingIssuedAt() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n\nURI: https://example.com\nVersion: 1\nChain ID: 1\nNonce: n"
        );
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_emptyIssuedAt() public {
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(_siwe("example.com", vm.toString(_signer), "", "https://example.com", "1", "1", "n", ""));
    }

    function test_parse_revert_missingChainId() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n\nURI: https://example.com\nVersion: 1\nNonce: n\nIssued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEMissingField.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_nonNumericChainId() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse(
            _siwe(
                "example.com", vm.toString(_signer), "", "https://example.com", "1", "1a", "n", "2024-01-01T00:00:00Z"
            )
        );
    }

    function test_parse_revert_emptyChainId() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse(
            _siwe("example.com", vm.toString(_signer), "", "https://example.com", "1", "", "n", "2024-01-01T00:00:00Z")
        );
    }

    function test_parse_revert_missingVersion() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n\nURI: https://example.com\nChain ID: 1\nNonce: n\nIssued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEVersionMismatch.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_versionNotOne() public {
        string memory message = string.concat(
            "example.com wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "\n",
            "URI: https://example.com\n",
            "Version: 2\n",
            "Chain ID: 1\n",
            "Nonce: n\n",
            "Issued At: 2024-01-01T00:00:00Z"
        );
        vm.expectRevert(SIWE.SIWEVersionMismatch.selector);
        this.exposedParse(message);
    }

    function test_parse_revert_versionZero() public {
        vm.expectRevert(SIWE.SIWEVersionMismatch.selector);
        this.exposedParse(
            _siwe("example.com", vm.toString(_signer), "", "https://example.com", "0", "1", "n", "2024-01-01T00:00:00Z")
        );
    }

    function test_parse_revert_emptyVersion() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse(
            _siwe("example.com", vm.toString(_signer), "", "https://example.com", "", "1", "n", "2024-01-01T00:00:00Z")
        );
    }

    function testFuzz_parse_revert_garbage(bytes memory garbage) public {
        vm.assume(garbage.length < 64);
        vm.expectRevert();
        this.exposedParse(string(garbage));
    }

    function testFuzz_parse_nonceUriChainId(string memory nonce, string memory uri, uint256 chainId) public view {
        vm.assume(bytes(nonce).length > 0 && bytes(nonce).length < 32);
        vm.assume(bytes(uri).length > 0 && bytes(uri).length < 64);
        vm.assume(!_hasLf(nonce) && !_hasLf(uri));

        string memory message = _siwe(
            "example.com", vm.toString(_signer), "", uri, "1", vm.toString(chainId), nonce, "2024-01-01T00:00:00Z"
        );
        SIWE.Message memory parsed = SIWE.parse(message);
        assertEq(parsed.nonce, nonce);
        assertEq(parsed.uri, uri);
        assertEq(parsed.chainId, chainId);
        assertEq(parsed.user, _signer);
        assertEq(parsed.domain, "example.com");
    }

    function exposedParse(string memory message) external pure returns (SIWE.Message memory) {
        return SIWE.parse(message);
    }
}
