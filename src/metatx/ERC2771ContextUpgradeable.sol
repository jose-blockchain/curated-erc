// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC2771} from "./IERC2771.sol";

/**
 * @title ERC2771ContextUpgradeable
 * @dev Upgradeable version of {ERC2771Context}. Uses ERC-7201 namespaced storage.
 *
 * The trusted forwarder is stored in namespaced storage and set during initialization.
 */
abstract contract ERC2771ContextUpgradeable is Initializable, ContextUpgradeable, IERC2771 {
    /// @custom:storage-location erc7201:curatedcontracts.storage.ERC2771Context
    struct ERC2771ContextStorage {
        address _trustedForwarder;
    }

    // keccak256(abi.encode(uint256(keccak256("curatedcontracts.storage.ERC2771Context")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC2771ContextStorageLocation =
        0xcb02b7e445645f5ec4ec81227c5a78439d4af2e73dbd751707a80038ed0d2400;

    function _getERC2771ContextStorage() private pure returns (ERC2771ContextStorage storage $) {
        assembly {
            $.slot := ERC2771ContextStorageLocation
        }
    }

    function __ERC2771Context_init(address trustedForwarder_) internal onlyInitializing {
        __ERC2771Context_init_unchained(trustedForwarder_);
    }

    function __ERC2771Context_init_unchained(address trustedForwarder_) internal onlyInitializing {
        ERC2771ContextStorage storage $ = _getERC2771ContextStorage();
        $._trustedForwarder = trustedForwarder_;
    }

    /// @inheritdoc IERC2771
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        ERC2771ContextStorage storage $ = _getERC2771ContextStorage();
        return forwarder == $._trustedForwarder;
    }

    function trustedForwarder() public view virtual returns (address) {
        ERC2771ContextStorage storage $ = _getERC2771ContextStorage();
        return $._trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
        }
        return super._msgSender();
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return msg.data[:calldataLength - contextSuffixLength];
        }
        return super._msgData();
    }

    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}
