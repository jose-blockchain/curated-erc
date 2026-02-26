// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in https://eips.ethereum.org/EIPS/eip-1363.
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`.
 */
interface IERC1363 is IERC20, IERC165 {
    /**
     * @dev Transfers tokens and then calls `onTransferReceived` on the recipient.
     * Reverts if the recipient does not implement {IERC1363Receiver} or rejects the callback.
     * @param to The address to transfer to.
     * @param value The amount to transfer.
     * @return True if the transfer and callback succeeded.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Transfers tokens and then calls `onTransferReceived` on the recipient with additional data.
     * @param to The address to transfer to.
     * @param value The amount to transfer.
     * @param data Additional data with no specified format.
     * @return True if the transfer and callback succeeded.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Transfers tokens from a sender and then calls `onTransferReceived` on the recipient.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to transfer.
     * @return True if the transfer and callback succeeded.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Transfers tokens from a sender and then calls `onTransferReceived` on the recipient
     * with additional data.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to transfer.
     * @param data Additional data with no specified format.
     * @return True if the transfer and callback succeeded.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Approves a spender and then calls `onApprovalReceived` on the spender.
     * @param spender The address to approve.
     * @param value The amount to approve.
     * @return True if the approval and callback succeeded.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Approves a spender and then calls `onApprovalReceived` on the spender with additional data.
     * @param spender The address to approve.
     * @param value The amount to approve.
     * @param data Additional data with no specified format.
     * @return True if the approval and callback succeeded.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}
