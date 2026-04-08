// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC7818} from "./IERC7818.sol";

/**
 * @title ERC7818
 * @dev ERC-20 extension implementing the epoch-based expiration mechanism
 */
abstract contract ERC7818 is Context, IERC7818, IERC20Metadata {
    // -------------------------------------------------------------------------
    // Errors — OZ custom error style
    // -------------------------------------------------------------------------

    /// @dev Thrown when minting / transferring to the zero address.
    error ERC7818InvalidReceiver(address receiver);

    /// @dev Thrown when transferring / burning from the zero address.
    error ERC7818InvalidSender(address sender);

    /// @dev Thrown when approving from or to the zero address.
    error ERC7818InvalidApprover(address approver);
    error ERC7818InvalidSpender(address spender);

    /// @dev Thrown when transferFrom exceeds the spender's allowance.
    error ERC7818InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    // -------------------------------------------------------------------------
    // Storage — strings as regular state vars (immutable not allowed for strings)
    // -------------------------------------------------------------------------

    string private _name;
    string private _symbol;

    // -------------------------------------------------------------------------
    // Immutables — value types only
    // -------------------------------------------------------------------------

    /// @dev TIME_BASED or BLOCKS_BASED.
    EPOCH_TYPE private immutable _epochType;

    /// @dev Length of one epoch in seconds (TIME_BASED) or blocks (BLOCKS_BASED).
    uint256 private immutable _epochDuration;

    /// @dev Number of consecutive epochs a minted batch remains valid.
    uint256 private immutable _validityPeriod;

    /// @dev block.timestamp or block.number at construction — epoch 0 anchor.
    uint256 private immutable _genesisPoint;

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    /// @dev Total tokens ever minted (includes expired — does not decrease on expiry).
    uint256 private _totalSupply;

    /// @dev ERC-20 allowances.
    mapping(address owner => mapping(address spender => uint256))
        private _allowances;

    /**
     * @dev Per-account per-epoch token balances.
     * _epochBalances[account][epoch] = amount held in that epoch bucket.
     */
    mapping(address account => mapping(uint256 epoch => uint256 amount))
        private _epochBalances;

    /**
     * @dev Ordered list of epochs in which `account` has ever received tokens.
     * Entries are never removed (lazy expiry); validity is checked on read.
     */
    mapping(address account => uint256[] epochs) private _epochList;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param name_           Token name.
     * @param symbol_         Token symbol.
     * @param epochDuration_  Length of one epoch (seconds or blocks). Must be > 0.
     * @param validityPeriod_ How many epochs a batch stays valid. Must be >= 1.
     * @param epochType_      TIME_BASED or BLOCKS_BASED.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 epochDuration_,
        uint256 validityPeriod_,
        EPOCH_TYPE epochType_
    ) {
        if (epochDuration_ == 0) revert("ERC7818: epochDuration must be > 0");
        if (validityPeriod_ == 0)
            revert("ERC7818: validityPeriod must be >= 1");

        _name = name_;
        _symbol = symbol_;
        _epochType = epochType_;
        _epochDuration = epochDuration_;
        _validityPeriod = validityPeriod_;
        _genesisPoint = _point();
    }

    // -------------------------------------------------------------------------
    // IERC20Metadata
    // -------------------------------------------------------------------------

    /// @inheritdoc IERC20Metadata
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC20Metadata
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    // -------------------------------------------------------------------------
    // IERC20 — supply & balances
    // -------------------------------------------------------------------------

    /**
     * @dev Returns total tokens ever minted, including expired ones.
     *
     * NOTE: This value does NOT decrease when tokens expire. Expired tokens
     * are excluded from {balanceOf} but remain counted in totalSupply until
     * explicitly burned.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the non-expired balance of `account`.
     *
     * Iterates the account's epoch list and sums only valid (non-expired)
     * buckets. This is O(n) where n = number of distinct epochs the account
     * has ever received tokens in.
     */
    function balanceOf(
        address account
    ) public view virtual returns (uint256 total) {
        uint256 current = currentEpoch();
        uint256[] storage epochs = _epochList[account];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len; ) {
            uint256 e = epochs[i];
            if (_epochValid(e, current)) {
                total += _epochBalances[account][e];
            }
            unchecked {
                ++i;
            }
        }
    }

    // -------------------------------------------------------------------------
    // IERC20 — transfers
    // -------------------------------------------------------------------------

    /**
     * @dev Transfers `value` tokens from the caller to `to`.
     * Consumes tokens FIFO (oldest valid epoch first).
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(_msgSender(), to, value);
        return true;
    }

    /**
     * @dev Transfers `value` tokens from `from` to `to` using the allowance mechanism.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value);
        return true;
    }

    // -------------------------------------------------------------------------
    // IERC20 — allowances
    // -------------------------------------------------------------------------

    /// @inheritdoc IERC20
    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @inheritdoc IERC20
    function approve(
        address spender,
        uint256 value
    ) public virtual returns (bool) {
        _approve(_msgSender(), spender, value);
        return true;
    }

    // -------------------------------------------------------------------------
    // IERC7818 — required
    // -------------------------------------------------------------------------

    /// @inheritdoc IERC7818
    function currentEpoch() public view virtual returns (uint256) {
        return (_point() - _genesisPoint) / _epochDuration;
    }

    /// @inheritdoc IERC7818
    function epochType() external view virtual returns (EPOCH_TYPE) {
        return _epochType;
    }

    /// @inheritdoc IERC7818
    function epochDuration() external view virtual returns (uint256) {
        return _epochDuration;
    }

    /// @inheritdoc IERC7818
    function validityPeriod() external view virtual returns (uint256) {
        return _validityPeriod;
    }

    /// @inheritdoc IERC7818
    function balanceOfAtEpoch(
        uint256 epoch,
        address account
    ) external view virtual returns (uint256) {
        if (!_epochValid(epoch, currentEpoch())) return 0;
        return _epochBalances[account][epoch];
    }

    // -------------------------------------------------------------------------
    // IERC7818 — optional
    // -------------------------------------------------------------------------

    /// @inheritdoc IERC7818
    function getEpochBalance(
        uint256 epoch,
        address account
    ) external view virtual returns (uint256) {
        return _epochBalances[account][epoch];
    }

    /// @inheritdoc IERC7818
    function getEpochInfo(
        uint256 epoch
    ) external view virtual returns (uint256 start, uint256 end) {
        start = _genesisPoint + epoch * _epochDuration;
        end = start + _epochDuration;
    }

    /// @inheritdoc IERC7818
    function getNearestExpiryOf(
        address account
    ) external view virtual returns (uint256 amount, uint256 expiry) {
        uint256 current = currentEpoch();
        uint256[] storage epochs = _epochList[account];
        uint256 len = epochs.length;
        uint256 nearest = type(uint256).max;

        for (uint256 i = 0; i < len; ) {
            uint256 e = epochs[i];
            if (_epochValid(e, current) && _epochBalances[account][e] > 0) {
                if (e < nearest) nearest = e;
            }
            unchecked {
                ++i;
            }
        }

        if (nearest == type(uint256).max) return (0, 0);

        amount = _epochBalances[account][nearest];
        expiry = _genesisPoint + (nearest + _validityPeriod) * _epochDuration;
    }

    // -------------------------------------------------------------------------
    // Internal — transfer
    // -------------------------------------------------------------------------

    /**
     * @dev Core transfer logic. Handles three distinct cases:
     *
     * 1. `value == 0`   — emit event, return early (no state change).
     * 2. `from == to`   — self-transfer; validate active balance, emit event,
     *                     no epoch bucket mutation (avoids double-count bug).
     * 3. Normal         — FIFO debit from `from`, credit `to` in the same epoch
     *                     bucket so the recipient inherits the original expiry.
     *
     * Reverts:
     * - {ERC7818InvalidSender}            if `from` is the zero address.
     * - {ERC7818InvalidReceiver}          if `to` is the zero address.
     * - {ERC7818TransferredExpiredToken}  if all remaining balance is expired
     *                                     (active balance was 0 to begin with).
     * - {ERC7818InsufficientActiveBalance} if active balance < value but > 0.
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) revert ERC7818InvalidSender(address(0));
        if (to == address(0)) revert ERC7818InvalidReceiver(address(0));

        if (value == 0) {
            emit Transfer(from, to, 0);
            return;
        }

        // ── Self-transfer ────────────────────────────────────────────────────
        // Mutating epoch buckets for from==to causes a double-count bug:
        // debit then credit the same slot within the same loop iteration.
        // Instead, just validate and emit.
        if (from == to) {
            uint256 active = balanceOf(from);
            if (active < value) {
                if (active == 0) {
                    revert ERC7818TransferredExpiredToken(
                        from,
                        _oldestNonEmptyEpoch(from)
                    );
                }
                revert ERC7818InsufficientActiveBalance(from, active, value);
            }
            emit Transfer(from, to, value);
            return;
        }

        // ── Normal transfer ──────────────────────────────────────────────────
        uint256 current = currentEpoch();
        uint256 remaining = value;
        uint256[] storage epochs = _epochList[from];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len && remaining > 0; ) {
            uint256 e = epochs[i];
            if (_epochValid(e, current)) {
                uint256 available = _epochBalances[from][e];
                if (available > 0) {
                    uint256 spend = available >= remaining
                        ? remaining
                        : available;
                    _epochBalances[from][e] -= spend;
                    remaining -= spend;
                    _credit(to, e, spend);
                }
            }
            unchecked {
                ++i;
            }
        }

        if (remaining > 0) {
            uint256 spent = value - remaining;
            uint256 active = spent; // tokens we did manage to find
            if (active == 0) {
                revert ERC7818TransferredExpiredToken(
                    from,
                    _oldestNonEmptyEpoch(from)
                );
            }
            revert ERC7818InsufficientActiveBalance(from, active, value);
        }

        emit Transfer(from, to, value);
    }

    // -------------------------------------------------------------------------
    // Internal — mint
    // -------------------------------------------------------------------------

    /**
     * @dev Mints `amount` tokens to `account` in the current epoch.
     *
     * Derived contracts MUST call this (not a raw ERC20 mint) to ensure
     * epoch tracking is applied correctly.
     */
    function _mintExpirable(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC7818InvalidReceiver(address(0));
        if (amount == 0) return;

        uint256 epoch = currentEpoch();
        _totalSupply += amount;
        _credit(account, epoch, amount);

        emit Transfer(address(0), account, amount);
        emit MintedInEpoch(account, epoch, amount);
    }

    // -------------------------------------------------------------------------
    // Internal — burn
    // -------------------------------------------------------------------------

    /**
     * @dev Burns `amount` tokens from `account` FIFO across valid epochs.
     *
     * Reverts with {ERC7818TransferredExpiredToken} if active balance is 0,
     * or {ERC7818InsufficientActiveBalance} if active balance > 0 but < amount.
     */
    function _burnExpirable(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC7818InvalidSender(address(0));
        if (amount == 0) return;

        uint256 current = currentEpoch();
        uint256 remaining = amount;
        uint256[] storage epochs = _epochList[account];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len && remaining > 0; ) {
            uint256 e = epochs[i];
            if (_epochValid(e, current)) {
                uint256 available = _epochBalances[account][e];
                if (available > 0) {
                    uint256 burn = available >= remaining
                        ? remaining
                        : available;
                    _epochBalances[account][e] -= burn;
                    remaining -= burn;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (remaining > 0) {
            uint256 active = amount - remaining;
            if (active == 0) {
                revert ERC7818TransferredExpiredToken(
                    account,
                    _oldestNonEmptyEpoch(account)
                );
            }
            revert ERC7818InsufficientActiveBalance(account, active, amount);
        }

        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    // -------------------------------------------------------------------------
    // Internal — allowance
    // -------------------------------------------------------------------------

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        if (owner == address(0)) revert ERC7818InvalidApprover(address(0));
        if (spender == address(0)) revert ERC7818InvalidSpender(address(0));
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 current = allowance(owner, spender);
        if (current != type(uint256).max) {
            if (current < value)
                revert ERC7818InsufficientAllowance(spender, current, value);
            unchecked {
                _allowances[owner][spender] = current - value;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Internal — epoch helpers
    // -------------------------------------------------------------------------

    /**
     * @dev Returns true when `target` epoch is within its validity window.
     *
     * epoch N is valid while: currentEpoch - N < validityPeriod
     */
    function _epochValid(
        uint256 target,
        uint256 current
    ) internal view virtual returns (bool) {
        if (target > current) return false;
        return (current - target) < _validityPeriod;
    }

    /**
     * @dev Credits `amount` to `account` in `epoch`.
     * Registers the epoch in the account's list on the first credit.
     */
    function _credit(address account, uint256 epoch, uint256 amount) private {
        if (_epochBalances[account][epoch] == 0 && amount > 0) {
            _epochList[account].push(epoch);
        }
        _epochBalances[account][epoch] += amount;
    }

    /**
     * @dev Returns block.timestamp (TIME_BASED) or block.number (BLOCKS_BASED).
     */
    function _point() internal view virtual returns (uint256) {
        return
            _epochType == EPOCH_TYPE.BLOCKS_BASED
                ? block.number
                : block.timestamp;
    }

    /**
     * @dev Returns the oldest epoch index with a non-zero raw balance for `account`.
     * Used to surface a meaningful epoch in revert errors.
     */
    function _oldestNonEmptyEpoch(
        address account
    ) private view returns (uint256) {
        uint256[] storage epochs = _epochList[account];
        uint256 len = epochs.length;
        for (uint256 i = 0; i < len; ) {
            if (_epochBalances[account][epochs[i]] > 0) return epochs[i];
            unchecked {
                ++i;
            }
        }
        return 0;
    }
}
