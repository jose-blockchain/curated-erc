// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC3156FlashLender} from "./IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";

/**
 * @title ERC3156FlashLender
 * @dev Abstract implementation of the {IERC3156FlashLender} interface.
 *
 * Provides a generic flash loan facility for any ERC-20 token held by this contract.
 * Subclasses must implement:
 * - {_flashFee} to define the fee model
 * - {_flashFeeReceiver} to define where fees go (address(0) = kept in lender)
 *
 * NOTE: This implementation does NOT support fee-on-transfer or deflationary tokens.
 * Using such tokens will result in balance accounting discrepancies.
 */
abstract contract ERC3156FlashLender is IERC3156FlashLender, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 private constant _CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error ERC3156UnsupportedToken(address token);
    error ERC3156CallbackFailed();
    error ERC3156ExceededMaxLoan(uint256 maxLoan);

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address token) public view virtual returns (uint256) {
        if (token.code.length == 0) return 0;
        try IERC20(token).balanceOf(address(this)) returns (uint256 balance) {
            return balance;
        } catch {
            return 0;
        }
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address token, uint256 amount) public view virtual returns (uint256) {
        if (!_supportedToken(token)) {
            revert ERC3156UnsupportedToken(token);
        }
        return _flashFee(token, amount);
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public virtual nonReentrant returns (bool) {
        uint256 maxLoan = maxFlashLoan(token);
        if (amount > maxLoan) {
            revert ERC3156ExceededMaxLoan(maxLoan);
        }

        uint256 fee = flashFee(token, amount);

        IERC20(token).safeTransfer(address(receiver), amount);

        bytes32 result = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        if (result != _CALLBACK_SUCCESS) {
            revert ERC3156CallbackFailed();
        }

        address feeReceiver = _flashFeeReceiver();
        IERC20(token).safeTransferFrom(address(receiver), address(this), amount);
        if (fee > 0 && feeReceiver != address(0)) {
            IERC20(token).safeTransferFrom(address(receiver), feeReceiver, fee);
        } else if (fee > 0) {
            IERC20(token).safeTransferFrom(address(receiver), address(this), fee);
        }

        return true;
    }

    /**
     * @dev Returns true if the token is supported for flash loans. Override to restrict tokens.
     * Default: returns true if maxFlashLoan > 0.
     *
     * NOTE: This default ties token support to current balance, meaning a temporarily
     * zero-balance token will cause flashFee to revert. Override with a whitelist for
     * production lenders.
     */
    function _supportedToken(address token) internal view virtual returns (bool) {
        return maxFlashLoan(token) > 0;
    }

    /**
     * @dev Returns the fee for a flash loan. Override to implement a fee model.
     */
    function _flashFee(address token, uint256 amount) internal view virtual returns (uint256);

    /**
     * @dev Returns the receiver of flash loan fees. Return address(0) to keep fees in the lender.
     */
    function _flashFeeReceiver() internal view virtual returns (address) {
        return address(0);
    }
}
