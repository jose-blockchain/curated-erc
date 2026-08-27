<p align="center">
  <img src="img/logo.jpg" alt="Curated ERC" width="400" />
</p>

# Curated ERC

> v0.5.0

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
| 3525 | Semi-Fungible Token | Token (ERC-721 compatible) |
| 1271 | Signature Validation for Contracts | Cryptography |
| 6492 | Predeploy Signature Validation | Cryptography |
| 2771 | Meta Transactions | Context / Gasless UX |
| 3156 | Flash Loans | DeFi / Finance |
| 7201 | Namespaced Storage Layout | Utils / Upgrades |
| 2535 | Diamonds (Multi-Facet Proxy) | Proxy / Upgrades |
| 4361 | Sign-In with Ethereum | Auth / Identity |
| 7818 | Expirable ERC-20 | Token (ERC-20 extension) |
| 8004 | Trustless Agents | AI Agents (identity, reputation, validation) |

16 standards implemented (non-upgradeable + upgradeable where applicable). Full plan across 40+ ERCs in [ROADMAP.md](./ROADMAP.md). Release history in [CHANGELOG.md](./CHANGELOG.md).

## Structure

```
src/
├── token/
│   ├── ERC1363/          # Payable Token (transfer/approve with callbacks)
│   ├── ERC2309/          # Consecutive Transfer (batch minting)
│   ├── ERC4906/          # Metadata Update Extension
│   ├── ERC3525/          # Semi-Fungible Token (slot + value model)
│   ├── ERC4907/          # Rental NFT (user/owner split with expiry)
│   ├── ERC5192/          # Soulbound NFT (non-transferable)
│   ├── ERC5484/          # Consensual Soulbound Tokens (burn authorization)
│   └── ERC7818/          # Expirable ERC-20 (epoch-based expiry)
├── metatx/               # ERC-2771 Trusted Forwarder context
├── finance/              # ERC-3156 Flash Loan lender
├── diamond/              # ERC-2535 Diamonds (multi-facet proxy)
├── auth/                 # ERC-4361 Sign-In with Ethereum
│   ├── SIWE.sol          # Library: ERC-191 hash, verify, parse message
│   ├── SIWEParser.sol    # Stateless on-chain parser (no signature check)
│   └── SIWEVerifier.sol  # Stateless on-chain verifier contract
├── agent/                # ERC-8004 Trustless Agents
│   ├── ERC8004IdentityRegistry(.sol|Upgradeable.sol)
│   ├── ERC8004ReputationRegistry(.sol|Upgradeable.sol)
│   └── ERC8004ValidationRegistry(.sol|Upgradeable.sol)
└── utils/
    ├── cryptography/     # ERC-1271 + ERC-6492 Signature validation
    └── StorageSlot7201.sol
```

Each ERC typically ships as:
- `IERC*.sol` — Standard interface
- `ERC*.sol` — Non-upgradeable implementation (abstract base or deployable contract)
- `ERC*Upgradeable.sol` — Upgradeable (Initializable + ERC-7201 namespaced storage)

Exceptions: **ERC-4361** exposes a library (`SIWE`) plus `SIWEParser` and `SIWEVerifier`; **ERC-6492** and **ERC-7201** are libraries/utilities; **ERC-8004** ships three deployable registry contracts per variant.

## Installation

### Foundry

```bash
forge install jose-compu/curated-erc
```

Add the remapping to your `remappings.txt`:

```
curated-erc/=lib/curated-erc/src/
```

Then import and extend:

```solidity
import {ERC1363} from "curated-erc/token/ERC1363/ERC1363.sol";
import {ERC3525} from "curated-erc/token/ERC3525/ERC3525.sol";
import {ERC5192} from "curated-erc/token/ERC5192/ERC5192.sol";
import {ERC4907} from "curated-erc/token/ERC4907/ERC4907.sol";

contract MySFT is ERC3525 {
    constructor() ERC3525("MySFT", "MSFT", 18) {}
    function mint(address to, uint256 slot, uint256 value) external returns (uint256) {
        return _mint(to, slot, value);
    }
}

contract MyPayableToken is ERC1363 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000e18);
    }
}
```

**ERC-4361 (SIWE)** — verify a signed login message on-chain:

```solidity
import {SIWE} from "curated-erc/auth/SIWE.sol";
import {SIWEVerifier} from "curated-erc/auth/SIWEVerifier.sol";

// Library (inline in your contract)
SIWE.VerificationParams memory params = SIWE.VerificationParams({
    message: siweMessage,
    signature: sig,
    signer: address(0),       // parse address from message
    chainId: block.chainid,
    domain: "app.example.com",
    nonce: expectedNonce,
    issuedAt: 0,
    expirationTime: expiry,
    notBefore: 0
});
address user = SIWE.verify(params);

// Or use the standalone verifier (emits SIWEVerified)
SIWEVerifier verifier = new SIWEVerifier();
address user = verifier.verify(params);
```

**ERC-7818 (Expirable ERC-20)** — tokens expire by epoch; `balanceOf` excludes expired buckets:

```solidity
import {ERC7818} from "curated-erc/token/ERC7818/ERC7818.sol";
import {IERC7818} from "curated-erc/token/ERC7818/IERC7818.sol";

contract MyExpirableToken is ERC7818 {
    constructor() ERC7818("MyToken", "MTK", 7 days, 2, IERC7818.EPOCH_TYPE.TIME_BASED) {}

    function mint(address to, uint256 amount) external {
        _mintExpirable(to, amount);
    }
}
```

**ERC-8004 (Trustless Agents)** — deploy the three registries as chain singletons:

```solidity
import {ERC8004IdentityRegistry} from "curated-erc/agent/ERC8004IdentityRegistry.sol";
import {ERC8004ReputationRegistry} from "curated-erc/agent/ERC8004ReputationRegistry.sol";
import {ERC8004ValidationRegistry} from "curated-erc/agent/ERC8004ValidationRegistry.sol";

ERC8004IdentityRegistry identity = new ERC8004IdentityRegistry();
ERC8004ReputationRegistry reputation =
    new ERC8004ReputationRegistry(address(identity), msg.sender);
ERC8004ValidationRegistry validation =
    new ERC8004ValidationRegistry(address(identity), msg.sender);

uint256 agentId = identity.register("ipfs://agent-registration.json");
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
import {SIWEVerifier} from "curated-erc/auth/SIWEVerifier.sol";
import {ERC8004IdentityRegistry} from "curated-erc/agent/ERC8004IdentityRegistry.sol";
```

### Hardhat (npm)

If you use Hardhat without Foundry, install from npm and add OpenZeppelin as dependencies:

1. Install the library and its peer dependencies:

```bash
npm install curated-erc @openzeppelin/contracts@5.5.0 @openzeppelin/contracts-upgradeable@5.5.0
```

2. Import and extend in your contracts:

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
forge build    # via-ir enabled for stack-heavy registry contracts
forge test -vv # 378 tests (unit + fuzz)
```

## Dependencies

- OpenZeppelin Contracts v5.5.0
- OpenZeppelin Contracts Upgradeable v5.5.0
- Forge Std v1.15.0

## License

MIT
