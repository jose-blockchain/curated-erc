<p align="center">
  <img src="img/logo.jpg" alt="Curated ERC" width="400" />
</p>

# Curated ERC

> v0.1.0

Canonical implementations of ERCs with real on-chain traction. Foundry-native, Solidity-tested.

## The Gap

OpenZeppelin covers the core 10 standards (ERC-20, 721, 1155, etc.) thoroughly. The next 30 ERCs — standards with thousands of deployments, millions in TVL, and active protocol adoption — have no audited, library-grade implementations. Developers copy from unaudited repos or roll their own.

Curated ERC Contracts fills that gap.

## Principles

- **Foundry-native, Solidity-tested** — no JS test harness, no Hardhat dependency
- **Non-upgradeable + Upgradeable** — both variants in one repo, upgradeable versions use ERC-7201 namespaced storage
- **OZ-grade quality** — NatSpec docs, custom errors, fuzz tests, internal security audits per contract
- **Curated, not exhaustive** — only ERCs with demonstrated on-chain adoption

## Implemented

| ERC | Name | Category |
|-----|------|----------|
| 1363 | Payable Token | Token (ERC-20 extension) |
| 5192 | Minimal Soulbound NFT | Token (ERC-721 extension) |
| 4907 | Rental NFT | Token (ERC-721 extension) |
| 4906 | Metadata Update Extension | Token (ERC-721 extension) |
| 5484 | Consensual Soulbound Tokens | Token (ERC-721 extension) |
| 2309 | Consecutive Transfer (Batch Mint) | Token (ERC-721 extension) |
| 1271 | Signature Validation for Contracts | Cryptography |
| 6492 | Predeploy Signature Validation | Cryptography |
| 2771 | Meta Transactions | Context / Gasless UX |
| 3156 | Flash Loans | DeFi / Finance |
| 7201 | Namespaced Storage Layout | Utils / Upgrades |

Full plan across 40 ERCs in [ROADMAP.md](./ROADMAP.md). Release history in [CHANGELOG.md](./CHANGELOG.md).

## Structure

```
src/
├── token/
│   ├── ERC1363/          # Payable Token (transfer/approve with callbacks)
│   ├── ERC2309/          # Consecutive Transfer (batch minting)
│   ├── ERC4906/          # Metadata Update Extension
│   ├── ERC4907/          # Rental NFT (user/owner split with expiry)
│   ├── ERC5192/          # Soulbound NFT (non-transferable)
│   └── ERC5484/          # Consensual Soulbound Tokens (burn authorization)
├── metatx/               # ERC-2771 Trusted Forwarder context
├── finance/              # ERC-3156 Flash Loan lender
└── utils/
    ├── cryptography/     # ERC-1271 + ERC-6492 Signature validation
    └── StorageSlot7201.sol
```

Each ERC ships as:
- `IERC*.sol` — Standard interface
- `ERC*.sol` — Non-upgradeable implementation
- `ERC*Upgradeable.sol` — Upgradeable (Initializable + ERC-7201 storage)

## Installation

### Foundry

```bash
forge install jose-blockchain/curated-erc
```

Add the remapping to your `remappings.txt`:

```
curated-erc/=lib/curated-erc/src/
```

Then import and extend:

```solidity
import {ERC1363} from "curated-erc/token/ERC1363/ERC1363.sol";
import {ERC5192} from "curated-erc/token/ERC5192/ERC5192.sol";
import {ERC4907} from "curated-erc/token/ERC4907/ERC4907.sol";

contract MyPayableToken is ERC1363 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000e18);
    }
}
```

### Hardhat

The recommended path is the [`@nomicfoundation/hardhat-foundry`](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-foundry) plugin, which lets Hardhat read `remappings.txt` and resolve imports from the `lib/` folder directly — no duplicate OpenZeppelin installs.

1. Install the plugin:

```bash
npm install --save-dev @nomicfoundation/hardhat-foundry
```

2. Add it to your `hardhat.config.ts`:

```typescript
import "@nomicfoundation/hardhat-foundry";
```

3. Clone curated-erc as a git submodule (same as Foundry):

```bash
forge install <your-github-user>/curated-erc
```

4. Add the remapping to `remappings.txt`:

```
curated-erc/=lib/curated-erc/src/
```

The plugin picks up remappings automatically. Imports work the same way as in Foundry:

```solidity
import {ERC4907} from "curated-erc/token/ERC4907/ERC4907.sol";
```

### Hardhat (npm)

If you use Hardhat without Foundry, install from npm and add OpenZeppelin as dependencies:

1. Install the library and its peer dependencies:

```bash
npm install curated-erc @openzeppelin/contracts@5.5.0 @openzeppelin/contracts-upgradeable@5.5.0
```

2. Import and extend in your contracts (same paths as Foundry):

```solidity
import {ERC1363} from "curated-erc/token/ERC1363/ERC1363.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyPayableToken is ERC1363 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000e18);
    }
}
```

Hardhat will compile the contracts in `node_modules/curated-erc` when resolving these imports; no extra config is needed. Use Solidity `^0.8.20` (e.g. `0.8.24`) in your `hardhat.config` to match the library.

## Development

```bash
forge install
forge build
forge test -vv
```

## Dependencies

- OpenZeppelin Contracts v5.5.0
- OpenZeppelin Contracts Upgradeable v5.5.0
- Forge Std v1.15.0

## License

MIT
