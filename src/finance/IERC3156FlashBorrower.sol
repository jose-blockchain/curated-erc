// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC3156FlashBorrower
 * @dev Interface of the ERC-3156 Flash Borrower.
 * See https://eips.ethereum.org/EIPS/eip-3156
 */
interface IERC3156FlashBorrower {
    /**
     * @dev Callback invoked by the flash lender during a flash loan.
     *
     * MUST return `keccak256("ERC3156FlashBorrower.onFlashLoan")` to accept the loan.
     * MUST have approved the lender to pull `amount + fee` of `token` before returning.
     *
     * @param initiator The address that initiated the flash loan.
     * @param token The token that was lent.
     * @param amount The amount that was lent.
     * @param fee The fee to be paid on top of the loan amount.
     * @param data Arbitrary data passed by the initiator.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan".
     */
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32);
}
