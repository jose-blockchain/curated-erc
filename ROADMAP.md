# Curated Contracts — Roadmap

Foundry-native, Solidity-tested reference implementations of ERCs with strong community traction.

Status is refreshed against **Final** ERCs with 2026 on-chain / protocol traction. Draft and Review standards stay on the watchlist until they finalize.

## Phase 1 — Tier 2 Core (ERCs with highest gap-to-traction ratio)

| ERC | Name | Status |
|-----|------|--------|
| 1363 | Payable Token | ✅ Done |
| 5192 | Minimal Soulbound NFT | ✅ Done |
| 4907 | Rental NFT | ✅ Done |
| 1271 | Signature Validation for Contracts | ✅ Done |
| 2771 | Meta Transactions (Trusted Forwarder) | ✅ Done |
| 3156 | Flash Loans | ✅ Done |
| 7201 | Namespaced Storage Layout | ✅ Done |
| 6492 | Signature Validation (Predeploy) | ✅ Done |

## Phase 2 — Tier 2 Advanced

| ERC | Name | Status |
|-----|------|--------|
| 2535 | Diamonds (Multi-Facet Proxy) | ✅ Done |
| 3525 | Semi-Fungible Token | ✅ Done |
| 3643 | T-REX (Regulated Tokens) | 🔲 [#23](https://github.com/jose-compu/curated-erc/issues/23) |
| 5564 | Stealth Addresses | 🔲 [#22](https://github.com/jose-compu/curated-erc/issues/22) |
| 6538 | Stealth Meta-Address Registry | 🔲 [#22](https://github.com/jose-compu/curated-erc/issues/22) |
| 4361 | Sign-In with Ethereum (SIWE Verifier) | ✅ Done |
| 7631 | Dual Nature Token Pair (DN404) | 🔲 [#21](https://github.com/jose-compu/curated-erc/issues/21) |
| 4337 | Account Abstraction (alt-mempool accounts) | 🔲 [#52](https://github.com/jose-compu/curated-erc/issues/52) |
| 7786 | Cross-Chain Messaging Gateway | 🔲 [#53](https://github.com/jose-compu/curated-erc/issues/53) |
| 7943 | uRWA Universal RWA Interface | 🔲 [#40](https://github.com/jose-compu/curated-erc/issues/40) |

## Phase 3 — Tier 3 (Niche, Growing)

| ERC | Name | Status |
|-----|------|--------|
| 4906 | Metadata Update Extension | ✅ Done |
| 2309 | Consecutive Transfer Extension | ✅ Done |
| 5484 | Consensual Soulbound Tokens | ✅ Done |
| 4626 | Tokenized Vaults | 🔲 [#41](https://github.com/jose-compu/curated-erc/issues/41) |
| 7540 | Async ERC-4626 Vaults | 🔲 [#25](https://github.com/jose-compu/curated-erc/issues/25) |
| 7575 | Multi-Asset ERC-4626 Vaults | 🔲 [#25](https://github.com/jose-compu/curated-erc/issues/25) |
| 5006 | Rental NFT (ERC-1155) | 🔲 [#32](https://github.com/jose-compu/curated-erc/issues/32) |
| 3668 | CCIP Read (Offchain Data) | 🔲 [#26](https://github.com/jose-compu/curated-erc/issues/26) |
| 6909 | Minimal Multi-Token Interface | 🔲 [#55](https://github.com/jose-compu/curated-erc/issues/55) |
| 5267 | EIP-712 Domain Retrieval | 🔲 [#56](https://github.com/jose-compu/curated-erc/issues/56) |

## Phase 4 — AI Agents & Agentic Economy

| ERC | Name | Status |
|-----|------|--------|
| 8004 | Trustless Agents (Identity / Reputation / Validation) | ✅ Done |
| 7857 | AI Agents NFT with Private Metadata | 🔲 [#54](https://github.com/jose-compu/curated-erc/issues/54) |

## Phase 5 — Tier 4 (Emerging, Final)

| ERC | Name | Status |
|-----|------|--------|
| 7092 | Financial Bonds | 🔲 [#31](https://github.com/jose-compu/curated-erc/issues/31) |
| 3475 | Abstract Storage Bonds | 🔲 Not started |
| 7751 | Wrapping Bubbled Reverts | 🔲 [#34](https://github.com/jose-compu/curated-erc/issues/34) |
| 7818 | Expirable ERC-20 | ✅ Done |
| 8042 | Diamond Storage | 🔲 [#30](https://github.com/jose-compu/curated-erc/issues/30) |

## Phase 6 — Watchlist (high 2026 traction, not Final yet)

Do not implement as “canonical Final” until status flips. Track for the next roadmap pass.

| ERC | Name | Status (EIP) | Why watch |
|-----|------|--------------|-----------|
| 6551 | Token Bound Accounts | Review | NFT-owned smart accounts; agent wallets |
| 7579 | Minimal Modular Smart Accounts | Draft | De-facto module ABI (Safe, ZeroDev, Biconomy, Rhinestone) |
| 7702 | Set EOA code | Final *(core EIP, not an ERC library)* | Pectra; pairs with 4337 / 7821 delegations |
| 7821 | Minimal Batch Executor | Draft | 7702 approve+swap batches (Solady / OZ authors) |
| 7683 | Cross-Chain Intents | Draft | Across / Uniswap intent settlement |
| 7930 | Interoperable Addresses | Review | Required by Final ERC-7786; ship codec with #53 |
| 7677 | Paymaster Web Service Capability | Review | Wallet JSON-RPC (5792), not a Solidity primitive |
| 3009 | Transfer With Authorization | Draft | USDC / x402 gasless transfers |

## Per-ERC Workflow

1. Interface definition (IERC*.sol)
2. Non-upgradeable implementation
3. Upgradeable implementation (ERC7201 namespaced storage + Initializable)
4. Full test suite (unit + fuzz)
5. Internal security audit
6. Documentation (NatSpec)
