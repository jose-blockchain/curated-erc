// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC2771} from "./IERC2771.sol";

/**
 * @title ERC2771Context
 * @dev Context variant for ERC-2771 meta-transactions. When the caller is the trusted
 * forwarder, `_msgSender()` and `_msgData()` extract the original sender and data from the
 * calldata suffix appended by the forwarder.
 *
 * See https://eips.ethereum.org/EIPS/eip-2771
 *
 * The trusted forwarder is immutable to prevent post-deployment attacks. For multi-forwarder
 * scenarios, override {isTrustedForwarder}.
 */
abstract contract ERC2771Context is Context, IERC2771 {
    address private immutable _trustedForwarder;

    /**
     * @dev Sets the trusted forwarder. This is immutable — set once at deployment.
     * @param trustedForwarder_ Address of the trusted forwarder contract.
     */
    constructor(address trustedForwarder_) {
        _trustedForwarder = trustedForwarder_;
    }

    /// @inheritdoc IERC2771
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    /**
     * @dev Returns the address of the trusted forwarder.
     */
    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @dev Extracts the sender from the calldata suffix when called by the trusted forwarder.
     * Falls back to `msg.sender` for direct calls.
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
        }
        return super._msgSender();
    }

    /**
     * @dev Extracts the original calldata (minus the appended sender) when called by the
     * trusted forwarder. Falls back to `msg.data` for direct calls.
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return msg.data[:calldataLength - contextSuffixLength];
        }
        return super._msgData();
    }

    /**
     * @dev The suffix length is 20 bytes (the sender address appended by the forwarder).
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}
