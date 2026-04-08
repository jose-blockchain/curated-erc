// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.x.x) (interfaces/IERC7818.sol)

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC7818
 * @dev Interface of the ERC-7818 Expirable ERC-20 standard.
 *
 * Extends {IERC20} with an epoch-based expiration mechanism. Tokens are
 * minted into discrete epochs; once an epoch has expired its tokens can no
 * longer be transferred. {IERC20-balanceOf} MUST exclude expired tokens.
 *
 * Epochs are measured in either UNIX seconds (TIME_BASED) or block numbers
 * (BLOCKS_BASED).
 */
interface IERC7818 is IERC20 {
    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    /**
     * @dev Epoch measurement strategy.
     *
     * - BLOCKS_BASED : one epoch = N blocks.
     * - TIME_BASED   : one epoch = N seconds (UNIX time).
     */
    enum EPOCH_TYPE {
        BLOCKS_BASED,
        TIME_BASED
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /**
     * @dev Thrown when a transfer is attempted with tokens from an expired epoch.
     *
     * @param sender The address that initiated the transfer.
     * @param epoch  The epoch whose tokens are expired.
     */
    error ERC7818TransferredExpiredToken(address sender, uint256 epoch);

    /**
     * @dev Thrown when a transfer or burn is attempted but the account does not
     * have enough non-expired (active) balance.
     *
     * @param account   The account with insufficient balance.
     * @param available The active balance available.
     * @param required  The amount requested.
     */
    error ERC7818InsufficientActiveBalance(
        address account,
        uint256 available,
        uint256 required
    );

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @dev Emitted when tokens are minted into a specific epoch.
     *
     * @param to    Recipient address.
     * @param epoch The epoch the tokens are minted into.
     * @param value Amount of tokens minted.
     */
    event MintedInEpoch(
        address indexed to,
        uint256 indexed epoch,
        uint256 value
    );

    // -------------------------------------------------------------------------
    // Required functions
    // -------------------------------------------------------------------------

    /**
     * @dev Returns the balance of `account` for a specific `epoch`.
     * MUST return 0 if `epoch` is expired.
     */
    function balanceOfAtEpoch(
        uint256 epoch,
        address account
    ) external view returns (uint256);

    /**
     * @dev Returns the current epoch index.
     */
    function currentEpoch() external view returns (uint256);

    /**
     * @dev Returns the epoch measurement type used by this contract.
     */
    function epochType() external view returns (EPOCH_TYPE);

    /**
     * @dev Returns the duration of one epoch in the unit defined by {epochType}.
     */
    function epochDuration() external view returns (uint256);

    /**
     * @dev Returns how many consecutive epochs a minted token batch remains valid.
     * Tokens minted in epoch N expire at the start of epoch N + validityPeriod.
     */
    function validityPeriod() external view returns (uint256);

    // -------------------------------------------------------------------------
    // Optional functions
    // -------------------------------------------------------------------------

    /**
     * @dev Returns the raw balance stored in `epoch` for `account`.
     * Unlike {balanceOfAtEpoch}, does NOT return 0 for expired epochs.
     */
    function getEpochBalance(
        uint256 epoch,
        address account
    ) external view returns (uint256);

    /**
     * @dev Returns the start (inclusive) and end (exclusive) of `epoch`
     * in the unit defined by {epochType}.
     */
    function getEpochInfo(
        uint256 epoch
    ) external view returns (uint256 start, uint256 end);

    /**
     * @dev Returns the token amount for `account` nearest to expiration and
     * the estimated block / timestamp at which it expires.
     * Returns (0, 0) when the account holds no valid tokens.
     */
    function getNearestExpiryOf(
        address account
    ) external view returns (uint256 amount, uint256 expiry);
}
