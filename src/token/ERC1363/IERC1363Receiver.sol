// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1363Receiver
 * @dev Interface for any contract that wants to support `transferAndCall` or `transferFromAndCall`
 * from ERC-1363 token contracts.
 */
interface IERC1363Receiver {
    /**
     * @dev Handles the receipt of ERC-1363 tokens. Called after a `transferAndCall` or
     * `transferFromAndCall` on an {IERC1363} token contract. To accept the transfer, this must
     * return `IERC1363Receiver.onTransferReceived.selector` (i.e. `0x88a7ca5c`).
     * @param operator The address that initiated the transfer (msg.sender on the token contract).
     * @param from The address which previously owned the tokens.
     * @param value The amount of tokens transferred.
     * @param data Additional data with no specified format.
     * @return `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))` if accepted.
     */
    function onTransferReceived(address operator, address from, uint256 value, bytes calldata data)
        external
        returns (bytes4);
}
