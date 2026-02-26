# Curated Contracts — Roadmap

Foundry-native, Solidity-tested reference implementations of ERCs with strong community traction.

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
| 2535 | Diamonds (Multi-Facet Proxy) | 🔲 Not started |
| 3525 | Semi-Fungible Token | 🔲 Not started |
| 3643 | T-REX (Regulated Tokens) | 🔲 Not started |
| 5564 | Stealth Addresses | 🔲 Not started |
| 6538 | Stealth Meta-Address Registry | 🔲 Not started |
| 4361 | Sign-In with Ethereum (SIWE Verifier) | 🔲 Not started |
| 7631 | Dual Nature Token Pair (DN404) | 🔲 Not started |

## Phase 3 — Tier 3 (Niche, Growing)

| ERC | Name | Status |
|-----|------|--------|
| 4906 | Metadata Update Extension | ✅ Done |
| 2309 | Consecutive Transfer Extension | ✅ Done |
| 5484 | Consensual Soulbound Tokens | ✅ Done |
| 7540 | Async ERC-4626 Vaults | 🔲 Not started |
| 7575 | Multi-Asset ERC-4626 Vaults | 🔲 Not started |
| 5006 | Rental NFT (ERC-1155) | 🔲 Not started |
| 3668 | CCIP Read (Offchain Data) | 🔲 Not started |

## Phase 4 — Tier 4 (Emerging)

| ERC | Name | Status |
|-----|------|--------|
| 7092 | Financial Bonds | 🔲 Not started |
| 3475 | Abstract Storage Bonds | 🔲 Not started |
| 7751 | Wrapping Bubbled Reverts | 🔲 Not started |
| 7818 | Expirable ERC-20 | 🔲 Not started |
| 8042 | Diamond Storage | 🔲 Not started |

## Per-ERC Workflow

1. Interface definition (IERC*.sol)
2. Non-upgradeable implementation
3. Upgradeable implementation (ERC7201 namespaced storage + Initializable)
4. Full test suite (unit + fuzz)
5. Internal security audit
6. Documentation (NatSpec)
