// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {IERC2309} from "./IERC2309.sol";

/**
 * @title ERC721Consecutive
 * @dev Extension of {ERC721} that supports batch minting via ERC-2309 {ConsecutiveTransfer} events.
 *
 * Batch minting is restricted to the constructor. Uses OZ's Checkpoints for O(log n) ownership
 * lookup and BitMaps for burn tracking. After construction, standard {_mint}/{_update} apply.
 *
 * NOTE: Individual minting via `_mint` is disabled during construction. Use {_mintConsecutive} instead.
 */
abstract contract ERC721Consecutive is ERC721, IERC2309 {
    using BitMaps for BitMaps.BitMap;
    using Checkpoints for Checkpoints.Trace160;

    Checkpoints.Trace160 private _sequentialOwnership;
    BitMaps.BitMap private _sequentialBurn;

    error ERC721ConsecutiveForbiddenBatchMint();
    error ERC721ConsecutiveExceededMaxBatch(uint256 batchSize, uint256 maxBatch);
    error ERC721ConsecutiveForbiddenMintDuringConstruction();

    /**
     * @dev Maximum batch size to accommodate off-chain indexers. Override to change.
     */
    function _maxBatchSize() internal view virtual returns (uint96) {
        return 5000;
    }

    /**
     * @dev Starting token ID for consecutive mints. Override to change.
     */
    function _firstConsecutiveId() internal view virtual returns (uint96) {
        return 0;
    }

    /**
     * @dev Mints `batchSize` consecutive tokens to `to`. Constructor-only.
     * Emits a single {ConsecutiveTransfer} event.
     * @return next The first token ID in this batch.
     */
    function _mintConsecutive(address to, uint96 batchSize) internal virtual returns (uint96) {
        uint96 next = _nextConsecutiveId();

        if (batchSize > 0) {
            if (address(this).code.length > 0) {
                revert ERC721ConsecutiveForbiddenBatchMint();
            }
            if (to == address(0)) {
                revert ERC721InvalidReceiver(address(0));
            }

            uint96 maxBatch = _maxBatchSize();
            if (batchSize > maxBatch) {
                revert ERC721ConsecutiveExceededMaxBatch(batchSize, maxBatch);
            }

            uint96 last = next + batchSize - 1;
            _sequentialOwnership.push(last, uint160(to));

            _increaseBalance(to, batchSize);

            emit ConsecutiveTransfer(next, last, address(0), to);
        }

        return next;
    }

    /**
     * @dev Returns the total number of consecutively-minted tokens.
     */
    function totalConsecutiveMinted() public view virtual returns (uint256) {
        (bool exists, uint96 latestId,) = _sequentialOwnership.latestCheckpoint();
        if (!exists) return 0;
        return uint256(latestId) - uint256(_firstConsecutiveId()) + 1;
    }

    /**
     * @dev Resolves ownership. Checks standard ERC721 storage first, then falls back to
     * sequential ownership checkpoints for batch-minted tokens.
     */
    function _ownerOf(uint256 tokenId) internal view virtual override returns (address) {
        address owner = super._ownerOf(tokenId);

        if (owner != address(0) || tokenId > type(uint96).max || tokenId < _firstConsecutiveId()) {
            return owner;
        }

        if (_sequentialBurn.get(tokenId)) {
            return address(0);
        }

        return address(_sequentialOwnership.lowerLookup(uint96(tokenId)));
    }

    /**
     * @dev Restricts individual minting during construction (use {_mintConsecutive} instead).
     * Records burns of consecutive tokens in the bitmap.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        if (previousOwner == address(0) && address(this).code.length == 0) {
            revert ERC721ConsecutiveForbiddenMintDuringConstruction();
        }

        if (to == address(0) && tokenId < _nextConsecutiveId() && !_sequentialBurn.get(tokenId)) {
            _sequentialBurn.set(tokenId);
        }

        return previousOwner;
    }

    function _nextConsecutiveId() private view returns (uint96) {
        (bool exists, uint96 latestId,) = _sequentialOwnership.latestCheckpoint();
        return exists ? latestId + 1 : _firstConsecutiveId();
    }
}
