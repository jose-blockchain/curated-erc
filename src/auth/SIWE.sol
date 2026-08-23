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
 *
 * {parse} performs a structured ERC-4361 field extract. Optional timestamps are kept as
 * ISO-8601 strings; callers convert them off-chain or pass unix times into {verify}.
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
    error SIWEInvalidFormat();
    error SIWEMissingField();

    /// @dev Structured ERC-4361 fields. Optional strings are empty when omitted.
    struct Message {
        string domain;
        address user;
        string statement;
        string uri;
        uint256 version;
        uint256 chainId;
        string nonce;
        string issuedAt;
        string expirationTime;
        string notBefore;
        string requestId;
    }

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
        (bool ok, bytes memory res) = account.staticcall(abi.encodeCall(IERC1271.isValidSignature, (digest, signature)));
        return ok && res.length >= 32 && abi.decode(res, (bytes4)) == _ERC1271_MAGIC_VALUE;
    }

    /**
     * @dev Parses required and optional ERC-4361 fields from `message`.
     * Reverts on a malformed header, address, version other than 1, or missing required fields.
     * Resource lists are ignored so an attacker cannot force unbounded allocation.
     */
    function parse(string memory message) internal pure returns (Message memory parsed) {
        bytes memory raw = bytes(message);
        bytes memory header = bytes(" wants you to sign in with your Ethereum account:\n");
        uint256 headerAt = _indexOf(raw, header, 0);
        if (headerAt == 0 || headerAt == type(uint256).max) {
            revert SIWEInvalidFormat();
        }
        parsed.domain = string(_slice(raw, 0, headerAt));
        if (_indexOf(bytes(parsed.domain), bytes("\n"), 0) != type(uint256).max) {
            revert SIWEInvalidFormat();
        }

        uint256 addrStart = headerAt + header.length;
        uint256 addrEnd = _indexOf(raw, bytes("\n"), addrStart);
        if (addrEnd == type(uint256).max) {
            revert SIWEInvalidAddressLine();
        }
        parsed.user = _parseHexAddress(_slice(raw, addrStart, addrEnd - addrStart));

        uint256 pos = addrEnd + 1;
        while (pos < raw.length && raw[pos] == 0x0a) {
            unchecked {
                ++pos;
            }
        }

        uint256 uriAt = _indexOf(raw, bytes("\nURI: "), pos);
        if (_startsWithAt(raw, pos, bytes("URI: "))) {
            parsed.statement = "";
        } else if (uriAt != type(uint256).max) {
            uint256 stmtEnd = uriAt;
            while (stmtEnd > pos && raw[stmtEnd - 1] == 0x0a) {
                unchecked {
                    --stmtEnd;
                }
            }
            parsed.statement = string(_slice(raw, pos, stmtEnd - pos));
            pos = uriAt + 1;
        } else {
            revert SIWEMissingField();
        }

        bool sawUri;
        bool sawVersion;
        bool sawChainId;
        bool sawNonce;
        bool sawIssuedAt;

        while (pos < raw.length) {
            uint256 nl = _indexOf(raw, bytes("\n"), pos);
            uint256 lineEnd = nl == type(uint256).max ? raw.length : nl;
            if (lineEnd > pos) {
                bytes memory line = _slice(raw, pos, lineEnd - pos);
                if (_startsWithAt(line, 0, bytes("URI: "))) {
                    parsed.uri = string(_slice(line, 5, line.length - 5));
                    sawUri = true;
                } else if (_startsWithAt(line, 0, bytes("Version: "))) {
                    parsed.version = _parseUint(_slice(line, 9, line.length - 9));
                    sawVersion = true;
                } else if (_startsWithAt(line, 0, bytes("Chain ID: "))) {
                    parsed.chainId = _parseUint(_slice(line, 10, line.length - 10));
                    sawChainId = true;
                } else if (_startsWithAt(line, 0, bytes("Nonce: "))) {
                    parsed.nonce = string(_slice(line, 7, line.length - 7));
                    sawNonce = true;
                } else if (_startsWithAt(line, 0, bytes("Issued At: "))) {
                    parsed.issuedAt = string(_slice(line, 11, line.length - 11));
                    sawIssuedAt = true;
                } else if (_startsWithAt(line, 0, bytes("Expiration Time: "))) {
                    parsed.expirationTime = string(_slice(line, 17, line.length - 17));
                } else if (_startsWithAt(line, 0, bytes("Not Before: "))) {
                    parsed.notBefore = string(_slice(line, 12, line.length - 12));
                } else if (_startsWithAt(line, 0, bytes("Request ID: "))) {
                    parsed.requestId = string(_slice(line, 12, line.length - 12));
                }
            }
            if (nl == type(uint256).max) break;
            pos = nl + 1;
        }

        if (
            !sawUri || bytes(parsed.uri).length == 0 || !sawNonce || bytes(parsed.nonce).length == 0 || !sawIssuedAt
                || bytes(parsed.issuedAt).length == 0 || !sawChainId
        ) {
            revert SIWEMissingField();
        }
        if (!sawVersion || parsed.version != 1) {
            revert SIWEVersionMismatch();
        }
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
        return _containsLiteral(message, string.concat(domain, " wants you to sign in with your Ethereum account:"));
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

    function _parseHexAddress(bytes memory addrBytes) private pure returns (address) {
        if (addrBytes.length != 42 || addrBytes[0] != "0" || addrBytes[1] != "x") {
            revert SIWEInvalidAddressLine();
        }
        bytes memory hexAddr = new bytes(20);
        for (uint256 i; i < 20; i++) {
            hexAddr[i] = bytes1(_fromHexChar(uint8(addrBytes[2 + i * 2])) << 4)
                | bytes1(_fromHexChar(uint8(addrBytes[3 + i * 2])));
        }
        return address(uint160(bytes20(hexAddr)));
    }

    function _parseUint(bytes memory data) private pure returns (uint256 result) {
        if (data.length == 0) revert SIWEInvalidFormat();
        for (uint256 i; i < data.length; i++) {
            uint8 c = uint8(data[i]);
            if (c < 48 || c > 57) revert SIWEInvalidFormat();
            result = result * 10 + (c - 48);
        }
    }

    function _indexOf(bytes memory data, bytes memory needle, uint256 start) private pure returns (uint256) {
        uint256 n = needle.length;
        if (n == 0 || start >= data.length || data.length - start < n) {
            return type(uint256).max;
        }
        uint256 last = data.length - n;
        for (uint256 i = start; i <= last; i++) {
            if (_startsWithAt(data, i, needle)) return i;
        }
        return type(uint256).max;
    }

    function _startsWithAt(bytes memory data, uint256 start, bytes memory prefix) private pure returns (bool) {
        uint256 n = prefix.length;
        if (start >= data.length || data.length - start < n) return false;
        for (uint256 i; i < n; i++) {
            if (data[start + i] != prefix[i]) return false;
        }
        return true;
    }

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory out) {
        if (len == 0) return out;
        if (start >= data.length || data.length - start < len) revert SIWEInvalidFormat();
        out = new bytes(len);
        for (uint256 i; i < len; i++) {
            out[i] = data[start + i];
        }
    }
}
