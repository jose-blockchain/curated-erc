# GOAL

Getting inspiration from `openzeppelin-contracts` and `openzeppelin-contracts-upgradeable` and want to implement inside folder `curated-erc` a Solidity library with ERC reference implementations. They have to be properly tested and secure. Follow OpenZeppelin style for Docs. Also Make sure to build a deatiled ROADMAP.md because we are going to start with a set of basic ERCs found in research of the traction and then keep adding more and more based on community traction. Below more context. Implement both version non-upgradeabl and upgradeable inside `curated-erc`, no need for 2 separated repos please.

The projects is called Curated Contracts, we focused on implementing reference implementations of ERCs with good community traction. Do internal security audits after finishing each contracts and after finishing all tests for each implemented contracts pls

So use Foundry, but don't market it against OZ's tooling choice. Market it as "Foundry-native, Solidity-tested" — that signals a philosophy, not just a build tool.

Make a detailed plan and roadmap so if we stop you can continue later; update CHANGELOG.md or ROADMAP.md as needed (please be brief).

# CONTEXT

Let me research this systematically. I'll look at GitHub usage and on-chain adoption data for the Final ERCs.Now let me compile this into a proper document. I have enough data to produce a well-reasoned ranking.40 ERCs ranked across 4 tiers. The key takeaway: **Tier 2 (ERCs 11–25) is your launch scope.** Those 15 standards have real on-chain adoption but no canonical, audited library — that's exactly the gap ERCref would fill.

A few highlights from the research:

- **ERC-2535 (Diamonds)** has the richest ecosystem gap — multiple ref impls exist but none are library-grade. Aavegotchi alone holds millions in diamond contracts.
- **ERC-5192 + 5484 (Soulbound)** are increasingly used for credentials/attestations but devs still roll their own.
- **ERC-5564/6538 (Stealth Addresses)** are Vitalik-backed privacy primitives with growing tooling but no standard library.
- **ERC-7631 (DN404)** just reached Final and is actively traded — very fresh opportunity.

The ~85 remaining Final ERCs were excluded for having negligible on-chain presence. Worth revisiting periodically but not worth the maintenance cost today.

# NAME

`curated-erc`. Lowercase with hyphen is the GitHub convention for repo names. The others look off in a URL: `github.com/jose-blockchain/curated-erc` reads cleanest.

# ROADMAP.md

# ERCref — Priority ERC Implementation List

## Methodology

Ranked by combining: on-chain deployment volume, GitHub import/reference frequency, DeFi/NFT protocol adoption, OpenZeppelin coverage (to identify the gap), and ecosystem momentum. ERCs already fully covered by OpenZeppelin are marked — these still belong in the repo for completeness but aren't where the project adds unique value.

---

## Tier 1 — High Traction, Core Infrastructure (Already Covered by OpenZeppelin)

These are table-stakes. Include them for completeness, but the real value-add is in Tiers 2–4.

| # | ERC | Name | Why It's Here | OZ Coverage |
|---|-----|------|---------------|-------------|
| 1 | 20 | Token Standard | Ubiquitous. Millions of deployments. | ✅ Full |
| 2 | 721 | Non-Fungible Token | De-facto NFT standard. | ✅ Full |
| 3 | 1155 | Multi Token Standard | Gaming, batch ops. Thousands of deployments. | ✅ Full |
| 4 | 165 | Standard Interface Detection | Used by nearly every ERC above. | ✅ Full |
| 5 | 2612 | Permit (ERC-20 Signed Approvals) | Gasless approvals. Very widely used in DeFi. | ✅ Full |
| 6 | 4626 | Tokenized Vaults | 760+ vaults cross-chain, $1.68B+ TVL. Yearn, Aave, Maker. | ✅ Full |
| 7 | 1967 | Proxy Storage Slots | Core upgrade pattern. Every proxy uses this. | ✅ Full |
| 8 | 2981 | NFT Royalty Standard | Widespread across L1/L2 NFT marketplaces. | ✅ Full |
| 9 | 1167 | Minimal Proxy Contract | Clones pattern. Extremely gas-efficient factory deployments. | ✅ Full |
| 10 | 6909 | Minimal Multi-Token Interface | Uniswap v4 core dependency. Rising fast. | ✅ Full (v5.2) |

---

## Tier 2 — Strong Traction, Gap in Quality Implementations (~15 ERCs)

**This is your highest-value target.** These have real adoption but lack OZ-grade implementations.

| # | ERC | Name | Traction Signal | OZ Coverage |
|---|-----|------|-----------------|-------------|
| 11 | 2535 | Diamonds (Multi-Facet Proxy) | Aavegotchi, Premia Finance, BarnBridge, active tooling ecosystem (Louper, DiamondScan). Multiple audited ref impls but no canonical library. | ❌ None |
| 12 | 1363 | Payable Token | ERC-20 extension for token payments with callback. Used in payment flows, growing DeFi adoption. | ❌ None |
| 13 | 4907 | Rental NFT | NFT rental marketplaces, gaming (Double Protocol). First ERC to formalize user/owner split. | ❌ None |
| 14 | 5192 | Minimal Soulbound NFTs | POAPs, credentials, attestations. Core primitive for on-chain identity. | ❌ None |
| 15 | 3525 | Semi-Fungible Token | Financial instruments — bonds, vesting, structured products. Solv Protocol built on it. | ❌ None |
| 16 | 2771 | Meta Transactions | GSN (Gas Station Network), Biconomy, OpenZeppelin Defender relay. Widely used for gasless UX. | ⚠️ Partial |
| 17 | 3643 | T-REX (Regulated Tokens) | Tokenized securities. Tokeny platform, 213 GitHub stars. First compliant token standard to reach Final. | ❌ None |
| 18 | 1271 | Signature Validation for Contracts | Account abstraction dependency. Safe, Argent, every smart wallet. | ⚠️ Interface only |
| 19 | 6492 | Signature Validation (Predeploy) | Complements 1271. Used by Safe, Ambire. Critical for AA wallets before deployment. | ❌ None |
| 20 | 5564 | Stealth Addresses | Privacy layer. Vitalik co-author. Umbra Protocol deployed. Growing privacy tooling. | ❌ None |
| 21 | 6538 | Stealth Meta-Address Registry | Companion to 5564. Same adoption vector. | ❌ None |
| 22 | 3156 | Flash Loans | Aave, dYdX, Uniswap. Core DeFi primitive. | ⚠️ ERC20FlashMint only |
| 23 | 4361 | Sign-In with Ethereum (SIWE) | Widely used off-chain auth standard. spruce-id/siwe library. Just reached Final in 2025. | ❌ (mostly JS, needs Solidity verifier) |
| 24 | 7201 | Namespaced Storage Layout | OpenZeppelin itself uses this internally. Upgrade-safe storage pattern. | ⚠️ Internal use |
| 25 | 7631 | Dual Nature Token Pair (DN404) | ERC-20/721 hybrid. Active trading. Vectorized (Solady) authored. Just reached Final. | ❌ None |

---

## Tier 3 — Moderate Traction, Niche but Growing (~10 ERCs)

| # | ERC | Name | Traction Signal | OZ Coverage |
|---|-----|------|-----------------|-------------|
| 26 | 6093 | Custom Errors for Tokens | OZ uses these errors internally but the standalone spec is useful for non-OZ codebases. | ⚠️ Integrated |
| 27 | 4906 | Metadata Update Extension | NFT marketplaces (OpenSea) index this event. Simple but widely needed. | ❌ None |
| 28 | 2309 | Consecutive Transfer Extension | Efficient batch minting (ERC721A pattern). Azuki, many PFP projects. | ❌ None |
| 29 | 5484 | Consensual Soulbound Tokens | Alternative SBT approach with consent mechanism. | ❌ None |
| 30 | 173 | Contract Ownership | Simple ownable. Many contracts use this minimal interface. | ⚠️ OZ has Ownable |
| 31 | 5267 | EIP-712 Domain Retrieval | Complements EIP-712 signing. Used by permit-based protocols. | ⚠️ Partial |
| 32 | 7540 | Async ERC-4626 Vaults | RWA protocols, cross-chain lending. Extends 4626 for real-world delays. | ❌ None |
| 33 | 7575 | Multi-Asset ERC-4626 Vaults | LP token vaults. Extends 4626 for multi-asset. | ❌ None |
| 34 | 5006 | Rental NFT (ERC-1155) | Parallel to 4907 but for 1155 tokens. Gaming use cases. | ❌ None |
| 35 | 3668 | CCIP Read (Offchain Data) | ENS uses this. Nick Johnson authored. Key for L2 data resolution. | ❌ None |

---

## Tier 4 — Emerging / Worth Watching (~5 ERCs)

| # | ERC | Name | Traction Signal | OZ Coverage |
|---|-----|------|-----------------|-------------|
| 36 | 7092 | Financial Bonds | On-chain bonds standard. Early but RWA narrative is strong. | ❌ None |
| 37 | 3475 | Abstract Storage Bonds | DeFi bonds/derivatives. DeBond protocol. | ❌ None |
| 38 | 7751 | Wrapping Bubbled Reverts | Error handling utility. OZ contributors co-authored. | ❌ None |
| 39 | 7818 | Expirable ERC-20 | Time-limited tokens (coupons, rewards). Just reached Final. | ❌ None |
| 40 | 8042 | Diamond Storage | Companion to 2535. Just reached Final. | ❌ None |

---

## Summary

| Tier | Count | Description | Priority |
|------|-------|-------------|----------|
| 1 | 10 | Core standards (OZ covered) | Include for completeness |
| 2 | 15 | **High-value gap** — strong traction, weak/no canonical impl | **Start here** |
| 3 | 10 | Moderate traction, niche growing | Phase 2 |
| 4 | 5 | Emerging, worth monitoring | Phase 3 |

**Recommended launch scope:** Tier 2 (ERCs 11–25). This is where ERCref adds the most value — standards with real adoption that developers currently have to implement from scratch or copy from unaudited repos.

## ERCs Excluded (Final but Low/No Traction)

The remaining ~85 Final ERCs were excluded due to minimal on-chain deployment, no significant GitHub references outside their own repos, or being superseded by newer standards (e.g., ERC-820 superseded by ERC-1820, ERC-777 largely deprecated in practice). These can be added later if adoption picks up.
