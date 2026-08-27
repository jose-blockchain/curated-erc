# Changelog

## [0.5.1] — 2026-08-27

### Fixed

- **ERC-2535 Diamond tests** — drop unused `vm.prank` before `new Diamond`; Foundry `stable` does not consume a prank on contract creation, which failed CI after merge ([#49](https://github.com/jose-compu/curated-erc/pull/49))

### Changed

- Standards gallery now uses a surrealist oil painting per ERC instead of procedural canvas fills ([#48](https://github.com/jose-compu/curated-erc/pull/48))

## [0.5.0] — 2026-08-27

### Added

- **ERC-7818** — Expirable ERC-20: epoch-based balances, FIFO spend across valid epochs, expired epochs excluded from `balanceOf`, time-based or block-based epochs, lazy expiry. Non-upgradeable + upgradeable ([#38](https://github.com/jose-compu/curated-erc/pull/38), closes [#29](https://github.com/jose-compu/curated-erc/issues/29))
- **ERC-4361 SIWE parser** — `SIWE.parse` returns structured message fields; `SIWEParser` exposes parse on-chain without verifying signatures ([#36](https://github.com/jose-compu/curated-erc/pull/36))

### Changed

- CI runs Foundry `fmt` / `build` / `test` automatically on pull requests
- **ERC-4907** — NatSpec `@notice` for rental / user-role semantics ([#46](https://github.com/jose-compu/curated-erc/pull/46), closes [#45](https://github.com/jose-compu/curated-erc/issues/45))

## [0.4.1] — 2026-07-21

### Fixed

- **npm publish** — `scripts/copy-src-to-root.js` now copies `auth/`, `agent/`, and `diamond/` so ERC-4361 (SIWE), ERC-8004, and ERC-2535 resolve for Hardhat/npm consumers (`curated-erc/auth/...`, etc.)
- **package metadata** — repository URL updated to `jose-compu/curated-erc`

### Notes

- Closes [#24](https://github.com/jose-compu/curated-erc/issues/24): ERC-4361 SIWE verifier shipped in 0.4.0; this patch ensures the `auth` tree is included in the published npm package.

## [0.4.0] — 2026-05-19

### Added

- **ERC-4361** — Sign-In with Ethereum: `SIWE` library, `SIWEVerifier` contract (ERC-191 signature + domain/chain/nonce/expiry checks)
- **ERC-8004** — Trustless Agents: Identity Registry (ERC-721 + metadata + EIP-712 agent wallet), Reputation Registry, Validation Registry (non-upgradeable + upgradeable)

### Changed

- Enabled `via_ir` in Foundry profile to compile stack-heavy registry contracts

## [0.2.1] — 2026-02-23

### Fixed

- **ERC-2535 Diamond** — Security audit: reject zero owner; require facet and init contracts have code; reject empty selector arrays; reject removal of immutable selectors in constructor initial cut.

## [0.2.0] — 2026-02-23

### Added

- **ERC-2535** — Diamonds (multi-facet proxy): IDiamond, IDiamondCut, IDiamondLoupe, LibDiamond, Diamond.sol; loupe + cut immutable on proxy; full test suite and AGENT.md (forge fmt check).

## [0.1.0] — 2026-02-23

Initial release. 11 ERCs implemented with non-upgradeable and upgradeable variants.

### Token Extensions

- **ERC-1363** — Payable Token (ERC-20 extension with transfer/approve callbacks)
- **ERC-5192** — Minimal Soulbound NFT (non-transferable ERC-721)
- **ERC-4907** — Rental NFT (time-limited user role for ERC-721)
- **ERC-4906** — Metadata Update Extension (ERC-721 metadata change events)
- **ERC-5484** — Consensual Soulbound Tokens (per-token burn authorization)
- **ERC-2309** — Consecutive Transfer (batch minting via Checkpoints + BitMaps)

### Cryptography

- **ERC-1271** — Signature Validation for Contracts
- **ERC-6492** — Predeploy Signature Validation (universal validator library)

### Meta-Transactions

- **ERC-2771** — Trusted Forwarder Context (gasless meta-transactions)

### DeFi / Finance

- **ERC-3156** — Flash Loans (generic ERC-20 flash lender)

### Utils / Upgrades

- **ERC-7201** — Namespaced Storage Layout (on-chain slot computation utility)

### Testing

- 174 tests across 11 suites (unit + fuzz), 0 failures
- 3 internal security audits with all findings resolved

### Dependencies

- Solidity ^0.8.20, compiled with 0.8.24
- OpenZeppelin Contracts v5.5.0
- OpenZeppelin Contracts Upgradeable v5.5.0
- Forge Std v1.15.0
