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
        return string.concat(
            "service.invalid wants you to sign in with your Ethereum account:\n",
            vm.toString(_signer),
            "\n",
            "\n",
            "I accept the ServiceOrg Terms of Service: https://service.invalid/tos\n",
            "\n",
            "URI: https://service.invalid/login\n",
            "Version: 1\n",
            "Chain ID: 1\n",
            "Nonce: 32891757\n",
            "Issued At: 2021-09-30T16:25:24.000Z"
        );
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
        assertEq(viaContract.user, viaLib.user);
        assertEq(viaContract.domain, viaLib.domain);
        assertEq(viaContract.nonce, viaLib.nonce);
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

    function test_parse_revert_empty() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse("");
    }

    function test_parse_revert_missingHeader() public {
        vm.expectRevert(SIWE.SIWEInvalidFormat.selector);
        this.exposedParse("not a siwe message");
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

    function testFuzz_parse_revert_garbage(bytes memory garbage) public {
        vm.assume(garbage.length < 64);
        vm.expectRevert();
        this.exposedParse(string(garbage));
    }

    function exposedParse(string memory message) external pure returns (SIWE.Message memory) {
        return SIWE.parse(message);
    }
}
