// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";

/**
 * @title IERC3156FlashLender
 * @dev Interface of the ERC-3156 Flash Lender.
 * See https://eips.ethereum.org/EIPS/eip-3156
 */
interface IERC3156FlashLender {
    /**
     * @dev Returns the maximum amount of `token` available for a flash loan.
     * @param token The address of the token.
     * @return The maximum flash loan amount.
     */
    function maxFlashLoan(address token) external view returns (uint256);

    /**
     * @dev Returns the fee for a flash loan of `amount` of `token`.
     * @param token The address of the token.
     * @param amount The amount of the flash loan.
     * @return The fee amount.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256);

    /**
     * @dev Initiates a flash loan.
     * @param receiver The receiver of the flash loan. Must implement {IERC3156FlashBorrower}.
     * @param token The token to be lent.
     * @param amount The amount to be lent.
     * @param data Arbitrary data to pass to the borrower's `onFlashLoan` callback.
     * @return True if the flash loan was successful.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}
