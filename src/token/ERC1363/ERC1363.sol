// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1363} from "./IERC1363.sol";
import {IERC1363Receiver} from "./IERC1363Receiver.sol";
import {IERC1363Spender} from "./IERC1363Spender.sol";

/**
 * @title ERC1363
 * @dev Implementation of the {IERC1363} interface.
 *
 * Extension of {ERC20} tokens that adds support for code execution on a recipient
 * after `transfer` or `transferFrom`, and on a spender after `approve`, following
 * EIP-1363: https://eips.ethereum.org/EIPS/eip-1363
 *
 * The receiver/spender must implement the corresponding callback interface to accept
 * the call; otherwise the transaction reverts.
 */
abstract contract ERC1363 is ERC20, ERC165, IERC1363 {
    /**
     * @dev Recipient rejected the token transfer.
     */
    error ERC1363InvalidReceiver(address receiver);

    /**
     * @dev Spender rejected the token approval.
     */
    error ERC1363InvalidSpender(address spender);

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1363).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC1363
    function transferAndCall(address to, uint256 value) public virtual returns (bool) {
        transfer(to, value);
        _checkOnTransferReceived(msg.sender, to, value, "");
        return true;
    }

    /// @inheritdoc IERC1363
    function transferAndCall(address to, uint256 value, bytes calldata data) public virtual returns (bool) {
        transfer(to, value);
        _checkOnTransferReceived(msg.sender, to, value, data);
        return true;
    }

    /// @inheritdoc IERC1363
    function transferFromAndCall(address from, address to, uint256 value) public virtual returns (bool) {
        transferFrom(from, to, value);
        _checkOnTransferReceived(from, to, value, "");
        return true;
    }

    /// @inheritdoc IERC1363
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data)
        public
        virtual
        returns (bool)
    {
        transferFrom(from, to, value);
        _checkOnTransferReceived(from, to, value, data);
        return true;
    }

    /// @inheritdoc IERC1363
    function approveAndCall(address spender, uint256 value) public virtual returns (bool) {
        approve(spender, value);
        _checkOnApprovalReceived(spender, value, "");
        return true;
    }

    /// @inheritdoc IERC1363
    function approveAndCall(address spender, uint256 value, bytes calldata data) public virtual returns (bool) {
        approve(spender, value);
        _checkOnApprovalReceived(spender, value, data);
        return true;
    }

    /**
     * @dev Calls `onTransferReceived` on the recipient. Reverts if the recipient does not
     * implement {IERC1363Receiver} or rejects the callback.
     */
    function _checkOnTransferReceived(address from, address to, uint256 value, bytes memory data) private {
        if (to.code.length == 0) {
            revert ERC1363InvalidReceiver(to);
        }

        try IERC1363Receiver(to).onTransferReceived(msg.sender, from, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Receiver.onTransferReceived.selector) {
                revert ERC1363InvalidReceiver(to);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ERC1363InvalidReceiver(to);
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Calls `onApprovalReceived` on the spender. Reverts if the spender does not
     * implement {IERC1363Spender} or rejects the callback.
     */
    function _checkOnApprovalReceived(address spender, uint256 value, bytes memory data) private {
        if (spender.code.length == 0) {
            revert ERC1363InvalidSpender(spender);
        }

        try IERC1363Spender(spender).onApprovalReceived(msg.sender, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Spender.onApprovalReceived.selector) {
                revert ERC1363InvalidSpender(spender);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ERC1363InvalidSpender(spender);
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
}
