# Changelog

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
