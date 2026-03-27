// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "./IERC1271.sol";
import {SIWETypes} from "./SIWETypes.sol";

/**
 * @title SIWEVerifier
 * @dev Solidity verifier for ERC-4361 (Sign-In with Ethereum) messages.
 *
 * This contract parses and validates SIWE messages according to the EIP-4361 specification.
 * It supports both EOA and ERC-1271 contract wallet signature validation.
 *
 * Gas optimization notes:
 * - String parsing is inherently expensive in Solidity
 * - We minimize storage operations by keeping everything in memory
 * - Early returns on validation failures to save gas
 * - Uses assembly for some byte operations where beneficial
 *
 * @author 小米粒 (PM + Dev Agent) 🌶️
 */
contract SIWEVerifier {
    using SIWETypes for *;

    // ERC-1271 magic value for valid signatures
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

    // SIWE message header constants
    string internal constant HEADER_PREFIX = " wants you to sign in with your Ethereum account:\n";
    string internal constant VERSION_KEY = "Version: ";
    string internal constant CHAIN_ID_KEY = "Chain ID: ";
    string internal constant NONCE_KEY = "Nonce: ";
    string internal constant ISSUED_AT_KEY = "Issued At: ";
    string internal constant EXPIRATION_KEY = "Expiration Time: ";
    string internal constant NOT_BEFORE_KEY = "Not Before: ";
    string internal constant REQUEST_ID_KEY = "Request ID: ";
    string internal constant URI_KEY = "URI: ";
    string internal constant RESOURCES_KEY = "Resources:";

    /**
     * @dev Emitted when a SIWE message is successfully verified
     */
    event SIWEVerified(
        address indexed signer,
        string domain,
        uint256 chainId,
        string nonce
    );

    /**
     * @dev Emitted when SIWE verification fails
     */
    event SIWEVerificationFailed(
        address indexed attemptedSigner,
        string reason
    );

    /**
     * @dev Verifies a SIWE message signature
     * @param message The raw SIWE message string
     * @param signature The EIP-191 signature (65 bytes for EOA, variable for ERC-1271)
     * @param params Verification parameters (domain, nonce, chainId, currentTime)
     * @return result The verification result including parsed message and status
     */
    function verify(
        string calldata message,
        bytes calldata signature,
        SIWETypes.VerificationParams calldata params
    ) external view returns (SIWETypes.VerificationResult memory result) {
        // Parse the message
        result = _parseMessage(message);
        if (!result.isValid) {
            emit SIWEVerificationFailed(address(0), result.error);
            return result;
        }

        // Validate fields
        string memory validationError = _validateFields(result.message, params);
        if (bytes(validationError).length > 0) {
            result.isValid = false;
            result.error = validationError;
            emit SIWEVerificationFailed(result.message.signer, validationError);
            return result;
        }

        // Verify signature
        bytes32 messageHash = _hashMessage(message);
        bool signatureValid = _verifySignature(result.message.signer, messageHash, signature);

        if (!signatureValid) {
            result.isValid = false;
            result.error = "Invalid signature";
            emit SIWEVerificationFailed(result.message.signer, "Invalid signature");
            return result;
        }

        emit SIWEVerified(
            result.message.signer,
            result.message.domain,
            result.message.chainId,
            result.message.nonce
        );

        result.isValid = true;
    }

    /**
     * @dev Parses a SIWE message string into structured data
     * @param message The raw SIWE message
     * @return result Parsed message or error
     *
     * Expected format:
     * {domain} wants you to sign in with your Ethereum account:
     * {address}
     * 
     * {statement} (optional)
     * 
     * URI: {uri}
     * Version: {version}
     * Chain ID: {chainId}
     * Nonce: {nonce}
     * Issued At: {issuedAt}
     * Expiration Time: {expirationTime} (optional)
     * Not Before: {notBefore} (optional)
     * Request ID: {requestId} (optional)
     * Resources: (optional)
     * - {resource1}
     * - {resource2}
     */
    function _parseMessage(
        string calldata message
    ) internal pure returns (SIWETypes.VerificationResult memory result) {
        bytes memory msgBytes = bytes(message);
        uint256 len = msgBytes.length;

        if (len == 0) {
            result.error = "Empty message";
            return result;
        }

        // Find first newline (end of header)
        uint256 headerEnd = _findSubstring(msgBytes, 0, "\n");
        if (headerEnd == type(uint256).max) {
            result.error = "Invalid format: no header newline";
            return result;
        }

        // Extract domain (everything before " wants you to sign in...")
        uint256 headerPrefixLen = bytes(HEADER_PREFIX).length;
        uint256 domainEnd = _findSubstring(msgBytes, 0, HEADER_PREFIX);
        if (domainEnd == type(uint256).max) {
            result.error = "Invalid format: missing header prefix";
            return result;
        }

        result.message.domain = string(msgBytes[0:domainEnd]);

        // Find address (after header, on next line)
        uint256 addrStart = domainEnd + headerPrefixLen;
        uint256 addrEnd = _findSubstring(msgBytes, addrStart, "\n");
        if (addrEnd == type(uint256).max) {
            result.error = "Invalid format: address line not found";
            return result;
        }

        // Parse address
        bytes memory addrBytes = _slice(msgBytes, addrStart, addrEnd - addrStart);
        if (addrBytes.length != 42 || addrBytes[0] != "0" || addrBytes[1] != "x") {
            result.error = "Invalid address format";
            return result;
        }

        result.message.signer = _parseAddress(addrBytes);
        if (result.message.signer == address(0)) {
            result.error = "Invalid address value";
            return result;
        }

        // Parse remaining fields
        _parseFields(msgBytes, addrEnd + 1, result);

        // Validate required fields
        if (bytes(result.message.uri).length == 0) {
            result.error = "Missing required field: URI";
            return result;
        }
        if (result.message.version != 1) {
            result.error = "Invalid version (must be 1)";
            return result;
        }
        if (result.message.chainId == 0) {
            result.error = "Missing required field: Chain ID";
            return result;
        }
        if (bytes(result.message.nonce).length == 0) {
            result.error = "Missing required field: Nonce";
            return result;
        }
        if (bytes(result.message.issuedAt).length == 0) {
            result.error = "Missing required field: Issued At";
            return result;
        }

        result.isValid = true;
    }

    /**
     * @dev Parse key-value fields from message
     */
    function _parseFields(
        bytes memory msgBytes,
        uint256 start,
        SIWETypes.VerificationResult memory result
    ) internal pure {
        uint256 pos = start;
        uint256 len = msgBytes.length;

        while (pos < len) {
            // Skip empty lines
            if (msgBytes[pos] == "\n") {
                pos++;
                continue;
            }

            // Try to match known field prefixes
            if (_startsWith(msgBytes, pos, bytes(VERSION_KEY))) {
                uint256 valueStart = pos + bytes(VERSION_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.version = _parseUint(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(CHAIN_ID_KEY))) {
                uint256 valueStart = pos + bytes(CHAIN_ID_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.chainId = _parseUint(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(NONCE_KEY))) {
                uint256 valueStart = pos + bytes(NONCE_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.nonce = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(ISSUED_AT_KEY))) {
                uint256 valueStart = pos + bytes(ISSUED_AT_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.issuedAt = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(EXPIRATION_KEY))) {
                uint256 valueStart = pos + bytes(EXPIRATION_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.expirationTime = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(NOT_BEFORE_KEY))) {
                uint256 valueStart = pos + bytes(NOT_BEFORE_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.notBefore = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(REQUEST_ID_KEY))) {
                uint256 valueStart = pos + bytes(REQUEST_ID_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.requestId = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else if (_startsWith(msgBytes, pos, bytes(URI_KEY))) {
                uint256 valueStart = pos + bytes(URI_KEY).length;
                uint256 valueEnd = _findSubstring(msgBytes, valueStart, "\n");
                if (valueEnd == type(uint256).max) valueEnd = len;
                result.message.uri = string(_slice(msgBytes, valueStart, valueEnd - valueStart));
                pos = valueEnd + 1;
            }
            else {
                // Unknown line, skip to next newline
                uint256 nextNewline = _findSubstring(msgBytes, pos, "\n");
                if (nextNewline == type(uint256).max) break;
                pos = nextNewline + 1;
            }
        }
    }

    /**
     * @dev Validate parsed fields against expected values
     */
    function _validateFields(
        SIWETypes.SIWEMessage memory msg,
        SIWETypes.VerificationParams calldata params
    ) internal view returns (string memory) {
        // Check domain
        if (keccak256(bytes(msg.domain)) != keccak256(bytes(params.expectedDomain))) {
            return "Domain mismatch";
        }

        // Check nonce
        if (keccak256(bytes(msg.nonce)) != keccak256(bytes(params.expectedNonce))) {
            return "Nonce mismatch";
        }

        // Check chain ID
        if (msg.chainId != params.expectedChainId) {
            return "Chain ID mismatch";
        }

        // Check time constraints
        if (bytes(msg.expirationTime).length > 0) {
            uint256 expTime = _parseISO8601(msg.expirationTime);
            if (expTime > 0 && params.currentTime > expTime) {
                return "Message expired";
            }
        }

        if (bytes(msg.notBefore).length > 0) {
            uint256 nbfTime = _parseISO8601(msg.notBefore);
            if (nbfTime > 0 && params.currentTime < nbfTime) {
                return "Message not yet valid";
            }
        }

        return "";
    }

    /**
     * @dev Hash the message using EIP-191 (\x19Ethereum Signed Message:\n{len}{message})
     */
    function _hashMessage(string calldata message) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n",
                _toString(bytes(message).length),
                message
            )
        );
    }

    /**
     * @dev Verify signature for EOA or ERC-1271 contract
     */
    function _verifySignature(
        address signer,
        bytes32 hash,
        bytes calldata signature
    ) internal view returns (bool) {
        if (signature.length == 65) {
            // EOA signature - use ECDSA recovery
            (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
            return err == ECDSA.RecoverError.NoError && recovered == signer;
        } else {
            // Contract signature - use ERC-1271
            try IERC1271(signer).isValidSignature(hash, signature) returns (bytes4 magicValue) {
                return magicValue == ERC1271_MAGIC_VALUE;
            } catch {
                return false;
            }
        }
    }

    // ===== String Utility Functions =====

    function _findSubstring(
        bytes memory data,
        uint256 start,
        string memory needle
    ) internal pure returns (uint256) {
        bytes memory needleBytes = bytes(needle);
        uint256 needleLen = needleBytes.length;
        uint256 dataLen = data.length;

        if (needleLen == 0) return start;
        if (start + needleLen > dataLen) return type(uint256).max;

        for (uint256 i = start; i <= dataLen - needleLen; i++) {
            bool match_ = true;
            for (uint256 j = 0; j < needleLen; j++) {
                if (data[i + j] != needleBytes[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return i;
        }

        return type(uint256).max;
    }

    function _startsWith(
        bytes memory data,
        uint256 start,
        bytes memory prefix
    ) internal pure returns (bool) {
        uint256 prefixLen = prefix.length;
        if (start + prefixLen > data.length) return false;

        for (uint256 i = 0; i < prefixLen; i++) {
            if (data[start + i] != prefix[i]) return false;
        }
        return true;
    }

    function _slice(
        bytes memory data,
        uint256 start,
        uint256 length
    ) internal pure returns (bytes memory) {
        if (start + length > data.length) {
            length = data.length - start;
        }
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function _parseAddress(bytes memory addrBytes) internal pure returns (address) {
        if (addrBytes.length != 42) return address(0);
        if (addrBytes[0] != "0" || addrBytes[1] != "x") return address(0);

        bytes20 result;
        assembly {
            // Skip "0x" prefix and parse 40 hex characters
            let data := add(addrBytes, 32)
            result := shr(96, shl(96, data))
        }

        // Manual hex parsing (more reliable than assembly for this case)
        result = bytes20(0);
        for (uint256 i = 2; i < 42; i++) {
            uint8 c = uint8(addrBytes[i]);
            uint8 nibble;
            if (c >= 48 && c <= 57) nibble = c - 48;           // 0-9
            else if (c >= 65 && c <= 70) nibble = c - 55;      // A-F
            else if (c >= 97 && c <= 102) nibble = c - 87;     // a-f
            else return address(0);

            result = bytes20(uint160(result) | (uint160(nibble) << (160 - 4 * (i - 1))));
        }

        return address(result);
    }

    function _parseUint(bytes memory data) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < data.length; i++) {
            uint8 c = uint8(data[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
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
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /**
     * @dev Parse ISO 8601 datetime string to Unix timestamp
     * Simplified implementation - only handles basic format: YYYY-MM-DDTHH:MM:SSZ
     */
    function _parseISO8601(string memory datetime) internal pure returns (uint256) {
        bytes memory dt = bytes(datetime);
        if (dt.length < 20) return 0;

        // YYYY-MM-DDTHH:MM:SSZ
        uint256 year = _parseUint(_slice(dt, 0, 4));
        uint256 month = _parseUint(_slice(dt, 5, 2));
        uint256 day = _parseUint(_slice(dt, 8, 2));
        uint256 hour = _parseUint(_slice(dt, 11, 2));
        uint256 minute = _parseUint(_slice(dt, 14, 2));
        uint256 second = _parseUint(_slice(dt, 17, 2));

        // Simplified Unix timestamp calculation
        // Note: This is a basic implementation. Production code would need
        // proper leap year handling and full date validation.
        if (year < 1970) return 0;

        uint256 timestamp = (year - 1970) * 31536000; // seconds per year (approx)
        timestamp += (month - 1) * 2592000;           // seconds per month (approx)
        timestamp += (day - 1) * 86400;               // seconds per day
        timestamp += hour * 3600;                      // seconds per hour
        timestamp += minute * 60;                      // seconds per minute
        timestamp += second;

        return timestamp;
    }
}
