// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.x.x) (token/ERC20/extensions/ERC7818Upgradeable.sol)

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC7818} from "./IERC7818.sol";

/**
 * @title ERC7818Upgradeable
 * @dev Upgradeable variant of {ERC7818}.
 *
 * Uses ERC-7201 namespaced storage so the layout is stable across upgrades
 * and cannot collide with proxy or other extension slots.
 */
abstract contract ERC7818Upgradeable is
    Initializable,
    ContextUpgradeable,
    IERC7818,
    IERC20Metadata
{
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ERC7818InvalidReceiver(address receiver);
    error ERC7818InvalidSender(address sender);
    error ERC7818InvalidApprover(address approver);
    error ERC7818InvalidSpender(address spender);
    error ERC7818InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    // -------------------------------------------------------------------------
    // ERC-7201 namespaced storage
    // -------------------------------------------------------------------------

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC7818
    struct ERC7818Storage {
        // Metadata
        string name;
        string symbol;
        // Epoch config
        EPOCH_TYPE epochType;
        uint256 epochDuration;
        uint256 validityPeriod;
        uint256 genesisPoint;
        // Token accounting
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256)) allowances;
        mapping(address account => mapping(uint256 epoch => uint256 amount)) epochBalances;
        mapping(address account => uint256[] epochs) epochList;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC7818")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC7818StorageLocation =
        0x4e5f991bca30eca2d4643aea16e7974d6012cd52f0dbd1a6b41c79a5e9b59800;

    function _getERC7818Storage()
        private
        pure
        returns (ERC7818Storage storage $)
    {
        assembly {
            $.slot := ERC7818StorageLocation
        }
    }

    // -------------------------------------------------------------------------
    // Initializers
    // -------------------------------------------------------------------------

    function __ERC7818_init(
        string memory name_,
        string memory symbol_,
        uint256 epochDuration_,
        uint256 validityPeriod_,
        EPOCH_TYPE epochType_
    ) internal onlyInitializing {
        __Context_init();
        __ERC7818_init_unchained(
            name_,
            symbol_,
            epochDuration_,
            validityPeriod_,
            epochType_
        );
    }

    function __ERC7818_init_unchained(
        string memory name_,
        string memory symbol_,
        uint256 epochDuration_,
        uint256 validityPeriod_,
        EPOCH_TYPE epochType_
    ) internal onlyInitializing {
        if (epochDuration_ == 0) revert("ERC7818: epochDuration must be > 0");
        if (validityPeriod_ == 0)
            revert("ERC7818: validityPeriod must be >= 1");

        ERC7818Storage storage $ = _getERC7818Storage();
        $.name = name_;
        $.symbol = symbol_;
        $.epochType = epochType_;
        $.epochDuration = epochDuration_;
        $.validityPeriod = validityPeriod_;
        $.genesisPoint = _point(epochType_);
    }

    // -------------------------------------------------------------------------
    // IERC20Metadata
    // -------------------------------------------------------------------------

    function name() public view virtual returns (string memory) {
        return _getERC7818Storage().name;
    }

    function symbol() public view virtual returns (string memory) {
        return _getERC7818Storage().symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    // -------------------------------------------------------------------------
    // IERC20
    // -------------------------------------------------------------------------

    function totalSupply() public view virtual returns (uint256) {
        return _getERC7818Storage().totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual returns (uint256 total) {
        ERC7818Storage storage $ = _getERC7818Storage();
        uint256 current = currentEpoch();
        uint256[] storage epochs = $.epochList[account];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len; ) {
            uint256 e = epochs[i];
            if (_epochValid($, e, current)) {
                total += $.epochBalances[account][e];
            }
            unchecked {
                ++i;
            }
        }
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(_msgSender(), to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
        return _getERC7818Storage().allowances[owner][spender];
    }

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

    function currentEpoch() public view virtual returns (uint256) {
        ERC7818Storage storage $ = _getERC7818Storage();
        return (_point($.epochType) - $.genesisPoint) / $.epochDuration;
    }

    function epochType() external view virtual returns (EPOCH_TYPE) {
        return _getERC7818Storage().epochType;
    }

    function epochDuration() external view virtual returns (uint256) {
        return _getERC7818Storage().epochDuration;
    }

    function validityPeriod() external view virtual returns (uint256) {
        return _getERC7818Storage().validityPeriod;
    }

    function balanceOfAtEpoch(
        uint256 epoch,
        address account
    ) external view virtual returns (uint256) {
        ERC7818Storage storage $ = _getERC7818Storage();
        if (!_epochValid($, epoch, currentEpoch())) return 0;
        return $.epochBalances[account][epoch];
    }

    // -------------------------------------------------------------------------
    // IERC7818 — optional
    // -------------------------------------------------------------------------

    function getEpochBalance(
        uint256 epoch,
        address account
    ) external view virtual returns (uint256) {
        return _getERC7818Storage().epochBalances[account][epoch];
    }

    function getEpochInfo(
        uint256 epoch
    ) external view virtual returns (uint256 start, uint256 end) {
        ERC7818Storage storage $ = _getERC7818Storage();
        start = $.genesisPoint + epoch * $.epochDuration;
        end = start + $.epochDuration;
    }

    function getNearestExpiryOf(
        address account
    ) external view virtual returns (uint256 amount, uint256 expiry) {
        ERC7818Storage storage $ = _getERC7818Storage();
        uint256 current = currentEpoch();
        uint256[] storage epochs = $.epochList[account];
        uint256 len = epochs.length;
        uint256 nearest = type(uint256).max;

        for (uint256 i = 0; i < len; ) {
            uint256 e = epochs[i];
            if (_epochValid($, e, current) && $.epochBalances[account][e] > 0) {
                if (e < nearest) nearest = e;
            }
            unchecked {
                ++i;
            }
        }

        if (nearest == type(uint256).max) return (0, 0);
        amount = $.epochBalances[account][nearest];
        expiry =
            $.genesisPoint +
            (nearest + $.validityPeriod) *
            $.epochDuration;
    }

    // -------------------------------------------------------------------------
    // Internal — transfer
    // -------------------------------------------------------------------------

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

        if (from == to) {
            uint256 active = balanceOf(from);
            if (active < value) {
                if (active == 0)
                    revert ERC7818TransferredExpiredToken(
                        from,
                        _oldestNonEmptyEpoch(_getERC7818Storage(), from)
                    );
                revert ERC7818InsufficientActiveBalance(from, active, value);
            }
            emit Transfer(from, to, value);
            return;
        }

        ERC7818Storage storage $ = _getERC7818Storage();
        uint256 current = currentEpoch();
        uint256 remaining = value;
        uint256[] storage epochs = $.epochList[from];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len && remaining > 0; ) {
            uint256 e = epochs[i];
            if (_epochValid($, e, current)) {
                uint256 available = $.epochBalances[from][e];
                if (available > 0) {
                    uint256 spend = available >= remaining
                        ? remaining
                        : available;
                    $.epochBalances[from][e] -= spend;
                    remaining -= spend;
                    _credit($, to, e, spend);
                }
            }
            unchecked {
                ++i;
            }
        }

        if (remaining > 0) {
            uint256 active = value - remaining;
            if (active == 0)
                revert ERC7818TransferredExpiredToken(
                    from,
                    _oldestNonEmptyEpoch($, from)
                );
            revert ERC7818InsufficientActiveBalance(from, active, value);
        }

        emit Transfer(from, to, value);
    }

    // -------------------------------------------------------------------------
    // Internal — mint / burn
    // -------------------------------------------------------------------------

    function _mintExpirable(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC7818InvalidReceiver(address(0));
        if (amount == 0) return;

        ERC7818Storage storage $ = _getERC7818Storage();
        uint256 epoch = currentEpoch();
        $.totalSupply += amount;
        _credit($, account, epoch, amount);

        emit Transfer(address(0), account, amount);
        emit MintedInEpoch(account, epoch, amount);
    }

    function _burnExpirable(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert ERC7818InvalidSender(address(0));
        if (amount == 0) return;

        ERC7818Storage storage $ = _getERC7818Storage();
        uint256 current = currentEpoch();
        uint256 remaining = amount;
        uint256[] storage epochs = $.epochList[account];
        uint256 len = epochs.length;

        for (uint256 i = 0; i < len && remaining > 0; ) {
            uint256 e = epochs[i];
            if (_epochValid($, e, current)) {
                uint256 available = $.epochBalances[account][e];
                if (available > 0) {
                    uint256 burn = available >= remaining
                        ? remaining
                        : available;
                    $.epochBalances[account][e] -= burn;
                    remaining -= burn;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (remaining > 0) {
            uint256 active = amount - remaining;
            if (active == 0)
                revert ERC7818TransferredExpiredToken(
                    account,
                    _oldestNonEmptyEpoch($, account)
                );
            revert ERC7818InsufficientActiveBalance(account, active, amount);
        }

        $.totalSupply -= amount;
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
        _getERC7818Storage().allowances[owner][spender] = value;
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
                _getERC7818Storage().allowances[owner][spender] =
                    current -
                    value;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Internal — epoch helpers
    // -------------------------------------------------------------------------

    function _epochValid(
        ERC7818Storage storage $,
        uint256 target,
        uint256 current
    ) internal view virtual returns (bool) {
        if (target > current) return false;
        return (current - target) < $.validityPeriod;
    }

    function _credit(
        ERC7818Storage storage $,
        address account,
        uint256 epoch,
        uint256 amount
    ) private {
        if ($.epochBalances[account][epoch] == 0 && amount > 0) {
            $.epochList[account].push(epoch);
        }
        $.epochBalances[account][epoch] += amount;
    }

    function _point(EPOCH_TYPE et) internal view virtual returns (uint256) {
        return et == EPOCH_TYPE.BLOCKS_BASED ? block.number : block.timestamp;
    }

    function _oldestNonEmptyEpoch(
        ERC7818Storage storage $,
        address account
    ) private view returns (uint256) {
        uint256[] storage epochs = $.epochList[account];
        uint256 len = epochs.length;
        for (uint256 i = 0; i < len; ) {
            if ($.epochBalances[account][epochs[i]] > 0) return epochs[i];
            unchecked {
                ++i;
            }
        }
        return 0;
    }
}
