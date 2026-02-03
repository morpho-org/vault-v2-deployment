# Morpho VaultV2 Deployment with MorphoMarketV1AdapterV2

---

## ⚠️ IMPORTANT DISCLAIMER ⚠️

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🚨 THIS REPOSITORY IS FOR DEMONSTRATION AND EDUCATIONAL PURPOSES ONLY 🚨   ║
║                                                                              ║
║   DO NOT USE IN PRODUCTION WITHOUT THOROUGH REVIEW AND TESTING              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Risk Warning

**The Morpho Association and contributors cannot be held responsible for ANY loss of funds, damages, or other consequences that may result from using this script or any associated code.**

**By using this repository, you explicitly acknowledge and accept that:**

1. **NO WARRANTY**: This code is provided "AS IS" without any warranties, guarantees, or representations of any kind, express or implied
2. **EDUCATIONAL ONLY**: This repository exists solely for educational and demonstration purposes to illustrate VaultV2 deployment concepts
3. **YOUR RESPONSIBILITY**: You are solely and entirely responsible for:
   - Understanding every line of code before deployment
   - Testing extensively on testnets before any mainnet interaction
   - Any funds, assets, or value that may be lost due to bugs, errors, vulnerabilities, or misuse
   - Ensuring compliance with all applicable laws and regulations
4. **SECURITY RISKS**: Smart contract deployment involves significant financial risk including but not limited to:
   - Complete loss of deposited funds
   - Vulnerability exploitation
   - Transaction failures
   - Gas cost overruns
5. **NOT AUDITED**: This code has NOT been professionally audited and may contain critical vulnerabilities
6. **NO SUPPORT**: No support, maintenance, or updates are guaranteed

### Before Using This Code

- [ ] Read and understand EVERY line of the deployment script
- [ ] Understand the VaultV2 architecture and Morpho protocol
- [ ] Test extensively on Anvil/local forks
- [ ] Test on testnet before mainnet
- [ ] Have your code reviewed by security professionals
- [ ] Understand the financial implications of each configuration choice
- [ ] Have a recovery plan if something goes wrong

**IF YOU DO NOT FULLY UNDERSTAND WHAT THIS CODE DOES, DO NOT USE IT.**

---

## Overview

This repository provides a **demonstration deployment solution** for Morpho VaultV2 using **MorphoMarketV1AdapterV2** for direct Morpho Blue market access.

### Key Features

- **Direct Market Access**: Connects directly to Morpho Blue markets, bypassing MetaMorpho (Vault V1)
- **3-Level Cap Structure**: adapter → collateral token → market params
- **Independent Adapter Timelocks**: Adapter has its own timelock system separate from the vault
- **Listing-Ready Configuration**: Includes all Morpho app listing requirements
- **Simulation-Friendly**: Gracefully handles simulation mode without real tokens

### Adapter Types

| Adapter | Use Case | Underlying |
|---------|----------|------------|
| **MorphoMarketV1AdapterV2** (this repo) | Direct Morpho Blue market access | Morpho Blue markets |
| MorphoVaultV1Adapter | Via MetaMorpho vault | Vault V1 (MetaMorpho) |

See VaultV2 deployment documentation [here](https://docs.morpho.org/learn/concepts/vault-v2/).

---

## Quick Start: Simulation Deployment on Base

### Prerequisites

1. [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
2. Clone this repository
3. Install dependencies: `forge install`

### Option 1: Using the .env File (Recommended)

The repository includes a pre-configured `.env` file for simulation:

```bash
# Load environment and run simulation
source .env && forge script script/DeployVaultV2WithMarketAdapter.s.sol \
  --fork-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  -vvv
```

### Option 2: Inline Environment Variables

```bash
# Simulate deployment on Base mainnet fork (no real transactions)
RPC_URL="https://mainnet.base.org" \
OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
ASSET=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a \
VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857 \
MORPHO_MARKET_V1_ADAPTER_V2_FACTORY=0x9a1B378C43BA535cDB89934230F0D3890c51C0EB \
VAULT_TIMELOCK_DURATION=259200 \
ADAPTER_TIMELOCK_DURATION=259200 \
forge script script/DeployVaultV2WithMarketAdapter.s.sol \
  --fork-url "$RPC_URL" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  -vvv
```

### Simulation Behavior

When running in simulation mode (without `--broadcast`), the script:

1. **Completes all deployment phases** (1-10)
2. **Gracefully skips dead deposits** if the deployer has no tokens:
   ```
   Phase 8: SKIPPED - Insufficient token balance for dead deposit
     Required: 1000000000000
     Available: 0
     NOTE: In production, ensure deployer has sufficient tokens
     The dead deposit is REQUIRED before the vault can accept external deposits
   ```
3. **Provides clear guidance** on what's needed for production deployment

This allows you to verify the entire deployment flow without needing real tokens.

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OWNER` | Final owner address | `0x1234...` |
| `ASSET` | Underlying asset token | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (USDC on Base) |
| `ADAPTER_REGISTRY` | Morpho adapter registry | `0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a` |
| `VAULT_V2_FACTORY` | VaultV2 factory | `0x4501125508079A99ebBebCE205DeC9593C2b5857` |
| `MORPHO_MARKET_V1_ADAPTER_V2_FACTORY` | Adapter factory | `0x9a1B378C43BA535cDB89934230F0D3890c51C0EB` |

### Optional Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CURATOR` | `OWNER` | Can manage vault parameters |
| `ALLOCATOR` | `OWNER` | Can allocate funds to adapters |
| `SENTINEL` | `address(0)` | Emergency role (optional) |

### Market Configuration (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `MARKET_ID` | `bytes32(0)` | Morpho Blue market ID (skip if 0) |
| `COLLATERAL_TOKEN_CAP` | `0` | Max allocation to collateral token |
| `MARKET_CAP` | `0` | Max allocation to specific market |

### Timelock Configuration (Listing Requirement)

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_TIMELOCK_DURATION` | `0` | Vault function timelocks (seconds) |
| `ADAPTER_TIMELOCK_DURATION` | `0` | Adapter function timelocks (seconds) |

**Note**: For Morpho app listing, timelocks must be >= 3 days (259200 seconds).

---

## Deployment Phases

| Phase | Description | Listing Requirement |
|-------|-------------|---------------------|
| 1 | Deploy VaultV2 instance via factory | - |
| 2 | Configure temporary permissions | - |
| 3 | Deploy MorphoMarketV1AdapterV2 | - |
| 4 | Submit timelocked configuration changes | - |
| 5 | Execute configuration + abdications | Non-custodial gates |
| 6 | Set final role assignments | - |
| 7 | Configure market and liquidity adapter | No idle liquidity |
| 8 | Execute vault dead deposit | Inflation protection |
| 9 | Configure vault timelocks | Timelock >= 3 days |
| 10 | Configure adapter timelocks | burnShares >= 3 days |

### Phase 8: Dead Deposit Behavior

The dead deposit (Phase 8) is **required for production** to protect against inflation attacks. In simulation mode:

- If deployer has sufficient tokens: deposit executes normally
- If deployer has insufficient tokens: phase is skipped with a warning

**For production deployment**, ensure the deployer address has at least:
- **USDC (6 decimals)**: 1,000,000 USDC (1e12 wei = $1)
- **WETH (18 decimals)**: 0.000000001 WETH (1e9 wei)

---

## Morpho App Listing Requirements Checklist

| Requirement | How Script Addresses It |
|-------------|------------------------|
| **No Idle Liquidity** | Phase 7: liquidityAdapter allocates deposits to market |
| **Vault Timelocks** | Phase 9: Configures timelocks for vault functions |
| **Adapter Timelocks** | Phase 10: Configures timelocks for adapter functions (burnShares >= 3 days) |
| **Naming Restriction** | Manual check: Name/symbol cannot contain "morpho" |
| **Dead Deposit** | Phase 8: 1e9-1e12 wei deposited to 0xdead |
| **Non-custodial Gates** | Phase 5: Gates abdicated (cannot be re-enabled) |

---

## Example .env File

```bash
# VaultV2 Deployment with MorphoMarketV1AdapterV2
# ⚠️ FOR DEMONSTRATION PURPOSES ONLY ⚠️

# Network
RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xYourPrivateKeyHere

# Role addresses
OWNER=0xYourOwnerAddress
CURATOR=0xYourCuratorAddress
ALLOCATOR=0xYourAllocatorAddress
SENTINEL=0xYourSentinelAddress

# Infrastructure (Base mainnet)
ASSET=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a
VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857
MORPHO_MARKET_V1_ADAPTER_V2_FACTORY=0x9a1B378C43BA535cDB89934230F0D3890c51C0EB

# First market (optional - set to 0x0 to skip)
MARKET_ID=0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836
COLLATERAL_TOKEN_CAP=1000000000000
MARKET_CAP=1000000000000

# Timelocks (3 days = 259200 seconds for listing)
VAULT_TIMELOCK_DURATION=259200
ADAPTER_TIMELOCK_DURATION=259200
```

---

## Running Tests

```bash
# Run all tests on Base mainnet fork
forge test --fork-url https://mainnet.base.org

# Run Market Adapter tests with verbose output
forge test --match-path test/DeployVaultV2WithMarketAdapter.t.sol -vvv

# Run specific test
forge test --match-test test_FullDeploymentWithTimelocks -vvv

# Run all tests (requires fork URL)
source .env && forge test --fork-url "$RPC_URL" -vvv
```

---

## Production Deployment

⚠️ **WARNING**: Production deployment involves real funds. Ensure you:
1. Have thoroughly tested on testnets
2. Understand all configuration parameters
3. Have the required token balance for dead deposits
4. Have your private key secured

```bash
# Deploy without verification
forge script script/DeployVaultV2WithMarketAdapter.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Deploy with Etherscan verification
forge script script/DeployVaultV2WithMarketAdapter.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify
```

---

## Troubleshooting

### Socket Error on macOS

If you encounter `Internal transport error: Socket operation on non-socket`, try:

```bash
# Clean forge cache and retry
forge clean && source .env && forge script script/DeployVaultV2WithMarketAdapter.s.sol \
  --fork-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  -vvv
```

### Phase 8 Skipped

If Phase 8 shows "SKIPPED - Insufficient token balance":
- This is expected in simulation mode without real tokens
- For production, ensure deployer has sufficient asset tokens

### Environment Variables Not Found

Ensure you source the `.env` file before running:
```bash
source .env
```

---

## Archived Scripts

Scripts in the `archives/` folder are for reference and historical purposes only. They are **NOT** actively maintained and should **NOT** be used for production deployments.

| Script | Description |
|--------|-------------|
| `archives/full.sol` | Complete Morpho ecosystem deployment (educational reference) |
| `archives/acrdx.sol` | ACRDX test environment deployment |

---

## Additional Resources

- [VaultV2 Documentation](https://docs.morpho.org/learn/concepts/vault-v2/)
- [Build Your Own Script Guide](docs/build_own_script.md)
- [Morpho Contract Addresses](https://docs.morpho.org/get-started/resources/addresses/#morpho-v2-contracts)

---

## License

This project is licensed under GPL-2.0-or-later.

---

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   Remember: This is DEMONSTRATION code. Use at your own risk.               ║
║   Always test thoroughly and understand what you're deploying.              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```
