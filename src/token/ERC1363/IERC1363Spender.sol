// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1363Spender
 * @dev Interface for any contract that wants to support `approveAndCall`
 * from ERC-1363 token contracts.
 */
interface IERC1363Spender {
    /**
     * @dev Handles the approval of ERC-1363 tokens. Called after an `approveAndCall` on an
     * {IERC1363} token contract. To accept the approval, this must return
     * `IERC1363Spender.onApprovalReceived.selector` (i.e. `0x7b04a2d0`).
     * @param owner The address which called `approveAndCall` on the token contract.
     * @param value The amount of tokens approved.
     * @param data Additional data with no specified format.
     * @return `bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))` if accepted.
     */
    function onApprovalReceived(
        address owner,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
