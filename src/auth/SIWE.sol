// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC1271} from "../utils/cryptography/IERC1271.sol";

/**
 * @title SIWE
 * @dev Library for ERC-4361 Sign-In with Ethereum on-chain verification.
 *
 * Verifies ERC-191 personal_sign signatures over SIWE plaintext messages and supports
 * optional field checks (chain ID, nonce, domain) via substring matching in the message body.
 */
library SIWE {
    bytes4 private constant _ERC1271_MAGIC_VALUE = 0x1626ba7e;

    error SIWEInvalidSignature();
    error SIWEAddressMismatch(address recovered, address expected);
    error SIWEChainIdMismatch(uint256 expected, uint256 found);
    error SIWEVersionMismatch();
    error SIWENonceMismatch();
    error SIWEDomainMismatch();
    error SIWEExpired();
    error SIWENotYetValid();
    error SIWEInvalidAddressLine();

    struct VerificationParams {
        string message;
        bytes signature;
        address signer;
        uint256 chainId;
        string domain;
        string nonce;
        uint256 issuedAt;
        uint256 expirationTime;
        uint256 notBefore;
    }

    /// @dev Returns the ERC-191 digest for a SIWE plaintext message.
    function hashMessage(string memory message) internal pure returns (bytes32) {
        return MessageHashUtils.toEthSignedMessageHash(bytes(message));
    }

    /// @dev Recovers the EOA signer from an ERC-191 digest. Returns zero on failure.
    function recoverSigner(bytes32 digest, bytes memory signature) internal pure returns (address) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signature);
        if (err != ECDSA.RecoverError.NoError) {
            return address(0);
        }
        return recovered;
    }

    /// @dev Returns true if `account` signed `digest` (EOA via ECDSA or ERC-1271 contract wallet).
    function isValidSignature(address account, bytes32 digest, bytes memory signature) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signature);
        if (err == ECDSA.RecoverError.NoError && recovered == account) {
            return true;
        }
        if (account.code.length == 0) {
            return false;
        }
        (bool ok, bytes memory res) =
            account.staticcall(abi.encodeCall(IERC1271.isValidSignature, (digest, signature)));
        return ok && res.length >= 32 && abi.decode(res, (bytes4)) == _ERC1271_MAGIC_VALUE;
    }

    /// @dev Parses the checksummed address line from a SIWE message.
    function parseAddress(string memory message) internal pure returns (address signer) {
        bytes memory msgBytes = bytes(message);
        uint256 lineStart = _accountLineStart(msgBytes);
        if (lineStart == type(uint256).max) {
            revert SIWEInvalidAddressLine();
        }
        uint256 lineEnd = lineStart;
        while (lineEnd < msgBytes.length && msgBytes[lineEnd] != 0x0a) {
            lineEnd++;
        }
        if (lineEnd - lineStart != 42 || msgBytes[lineStart] != "0" || msgBytes[lineStart + 1] != "x") {
            revert SIWEInvalidAddressLine();
        }
        bytes memory hexAddr = new bytes(20);
        for (uint256 i; i < 20; i++) {
            hexAddr[i] = bytes1(_fromHexChar(uint8(msgBytes[lineStart + 2 + i * 2])) << 4)
                | bytes1(_fromHexChar(uint8(msgBytes[lineStart + 3 + i * 2])));
        }
        return address(uint160(bytes20(hexAddr)));
    }

    /// @dev Verifies a SIWE message signature and optional binding fields.
    function verify(VerificationParams memory params) internal view returns (address signer) {
        bytes32 digest = hashMessage(params.message);
        signer = params.signer == address(0) ? parseAddress(params.message) : params.signer;

        if (!isValidSignature(signer, digest, params.signature)) {
            revert SIWEInvalidSignature();
        }

        if (params.signer != address(0) && signer != params.signer) {
            revert SIWEAddressMismatch(signer, params.signer);
        }

        if (params.chainId != 0) {
            if (!_containsChainId(params.message, params.chainId)) {
                revert SIWEChainIdMismatch(params.chainId, params.chainId);
            }
        }

        if (bytes(params.domain).length > 0 && !_containsDomain(params.message, params.domain)) {
            revert SIWEDomainMismatch();
        }

        if (bytes(params.nonce).length > 0 && !_containsNonce(params.message, params.nonce)) {
            revert SIWENonceMismatch();
        }

        if (!_containsVersionOne(params.message)) {
            revert SIWEVersionMismatch();
        }

        if (params.expirationTime != 0 && block.timestamp > params.expirationTime) {
            revert SIWEExpired();
        }

        if (params.notBefore != 0 && block.timestamp < params.notBefore) {
            revert SIWENotYetValid();
        }
    }

    function _accountLineStart(bytes memory msgBytes) private pure returns (uint256) {
        uint256 len = msgBytes.length;
        if (len < 43) return type(uint256).max;
        for (uint256 i; i + 42 < len; i++) {
            if (msgBytes[i] == 0x0a && i + 1 < len && msgBytes[i + 1] == "0" && msgBytes[i + 2] == "x") {
                return i + 1;
            }
        }
        return type(uint256).max;
    }

    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (c >= uint8(bytes1("0")) && c <= uint8(bytes1("9"))) {
            return c - uint8(bytes1("0"));
        }
        if (c >= uint8(bytes1("a")) && c <= uint8(bytes1("f"))) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (c >= uint8(bytes1("A")) && c <= uint8(bytes1("F"))) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert SIWEInvalidAddressLine();
    }

    function _containsVersionOne(string memory message) private pure returns (bool) {
        return _containsLiteral(message, "Version: 1");
    }

    function _containsChainId(string memory message, uint256 chainId) private pure returns (bool) {
        return _containsLiteral(message, string.concat("Chain ID: ", _toString(chainId)));
    }

    function _containsNonce(string memory message, string memory nonce) private pure returns (bool) {
        return _containsLiteral(message, string.concat("Nonce: ", nonce));
    }

    function _containsDomain(string memory message, string memory domain) private pure returns (bool) {
        return _containsLiteral(
            message, string.concat(domain, " wants you to sign in with your Ethereum account:")
        );
    }

    function _containsLiteral(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i; i + n.length <= h.length; i++) {
            bool matchAll = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matchAll = false;
                    break;
                }
            }
            if (matchAll) return true;
        }
        return false;
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}
