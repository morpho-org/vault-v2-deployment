# Morpho VaultV2 Deployment

#### ⚠️ DISCLAIMER

**This repository is provided for educational purposes only. The Morpho Association cannot be held responsible for any loss of funds, damages, or other consequences that may result from using this script or any associated code. Use at your own risk.**

**By using this script, you acknowledge that:**
- You understand the risks associated with smart contract deployment and cryptocurrency transactions
- You have thoroughly tested the script in a safe environment before any mainnet deployment
- You are solely responsible for any funds or assets that may be lost due to bugs, errors, or misuse
- The code is provided "as is" without any warranties or guarantees

**Please ensure you understand the code and test thoroughly before deploying to mainnet.**

---

## Overview 

This repository provides a "one-click" script to deploy a Morpho VaultV2 using a Morpho VaultV1 as an underlying liquidity market pool.

See VaultV2 deployment documentation [here](https://docs.morpho.org/learn/concepts/vault-v2/).

You can find a detailed explanation of the script, allowing you to build your own deployment script [here](docs/build_own_script.md).

The script will deploy the following smart contracts:

- A **VaultV2**
- A **VaultV1 Adapter**

You need to provide the following parameters as environment variables:

- `OWNER`: Address of the Owner
- `CURATOR`: Address of the Curator
- `ALLOCATOR`: Address of an Allocator
- `SENTINEL`: Address of a Sentinel
- `VAULT_V1`: Address of the VaultV1 to be used as the liquidity market.
- `TIMELOCK_DURATION`: Duration of the timelock in seconds to be set. Do not set this variable or set it to 0 if no timelock is needed.

Note: the Loan Token (the "asset") will be inferred from the VaultV1 configuration.

## Getting Started

### 1. Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Git](https://git-scm.com/)

### 2. Installation

1. Clone the repository:

   ```bash
   git clone git@github.com:morpho-org/vault-v2-deployment.git
   cd vault-v2-deployment
   ```

2. Install dependencies:
   This project uses git submodules for dependencies.
   ```bash
   git submodule update --init --recursive
   ```

### 3. Configure Environment Variables

Before deploying, you need to set up your environment variables. We provide a `.env.example` file as a template.

#### Option 1: Using .env file (Recommended)

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file with your actual values:
   ```bash
   # Edit the .env file with your preferred editor
   nano .env
   # or
   vim .env
   # or
   code .env
   ```

3. Fill in the required values:
   - `OWNER`: Address of the Owner role
   - `CURATOR`: Address of the Curator role  
   - `ALLOCATOR`: Address of the Allocator role
   - `SENTINEL`: Address of the Sentinel role (optional)
   - `VAULT_V1`: Address of the VaultV1 to use as liquidity market
   - `ADAPTER_REGISTRY`: Address of the Adapter Registry
   - `VAULT_V2_FACTORY`: Address of the VaultV2 Factory
   - `MORPHO_VAULT_V1_ADAPTER_FACTORY`: Address of the MorphoVaultV1 Adapter Factory
   - `RPC_URL`: Your RPC endpoint URL
   - `PRIVATE_KEY`: Your private key for deployment (keep secure!)
   - `TIMELOCK_DURATION`: Timelock duration in seconds (set to 0 for immediate execution)
   - `ETHERSCAN_API_KEY`: Optional, for contract verification

   **⚠️ Security Note**: Never commit your `.env` file to version control. It contains sensitive information like private keys. The `.env` file is already included in `.gitignore` to prevent accidental commits.

#### Option 2: Using export commands

Alternatively, you can set environment variables directly:

```bash
# Set environment variables
# Notes:
#      - These variables can also be put in .env file
#      - TIMELOCK_DURATION variable can be set to 0 or skipped
export OWNER=0xYourOwnerAddress
export CURATOR=0xYourCuratorAddress
export ALLOCATOR=0xYourAllocatorAddress
export SENTINEL=0xYourSentinelAddress
export VAULT_V1=0xTheVaultV1ToUse
export ADAPTER_REGISTRY=0xYourAdapterRegistryAddress
export VAULT_V2_FACTORY=0xYourVaultV2FactoryAddress
export MORPHO_VAULT_V1_ADAPTER_FACTORY=0xYourMorphoVaultV1AdapterFactoryAddress
export TIMELOCK_DURATION=TimelockDurationInSeconds
export RPC_URL=https://your-rpc-url.com
export PRIVATE_KEY=0xYourPrivateKey
```

### 4. Deploy VaultV2

This script deploys a new VaultV2 instance and its related contracts to run with a VaultV1 as Liquidity Market.

Run the script:

```bash
# Run the deployment script (without block explorer verification)
forge script script/DeployVaultV2.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

```bash
# Run the deployment script (with verification on Etherscan)
# Refer to Foundry documentation for non Etherscan block explorers
forge script script/DeployVaultV2.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify
```

## Testing Deployment

### Test Deployment on Anvil

For testing purposes, you can use the provided test deployment script that runs on a local Anvil instance:

```bash
# Run the test deployment script
./deploy_anvil.sh
```

This script will:
- Start a local Anvil blockchain
- Deploy mock contracts for testing
- Deploy the VaultV2 with test configuration
- Display deployment results and configuration
- Clean up and stop Anvil

**Note**: This is for testing only and uses temporary mock contracts. Do not use this for production deployments.

### GitHub Actions Integration

The repository includes GitHub Actions workflows for automated testing:

- **Test Workflow** (`.github/workflows/test.yml`): Runs tests, formatting, and build checks
- **Test Deployment Workflow** (`.github/workflows/test-deployment.yml`): Runs the test deployment script on Anvil

These workflows run automatically on pushes and pull requests, and can also be triggered manually.

## Quick Reference

### Environment Variables Summary

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `OWNER` | ✅ | Owner role address | `0x1234...` |
| `CURATOR` | ✅ | Curator role address | `0x5678...` |
| `ALLOCATOR` | ✅ | Allocator role address | `0x9abc...` |
| `SENTINEL` | ❌ | Sentinel role address | `0xdef0...` |
| `VAULT_V1` | ✅ | VaultV1 address to use | `0x1111...` |
| `ADAPTER_REGISTRY` | ✅ | Adapter Registry address | `0x3333...` |
| `VAULT_V2_FACTORY` | ✅ | VaultV2 Factory address | `0x4444...` |
| `MORPHO_VAULT_V1_ADAPTER_FACTORY` | ✅ | MorphoVaultV1 Adapter Factory address | `0x5555...` |
| `RPC_URL` | ✅ | RPC endpoint URL | `https://...` |
| `PRIVATE_KEY` | ✅ | Deployment private key | `0x2222...` |
| `TIMELOCK_DURATION` | ❌ | Timelock in seconds | `86400` (1 day) |
| `ETHERSCAN_API_KEY` | ❌ | For contract verification | `abc123...` |

### Common Commands

```bash
# Setup
cp .env.example .env
# Edit .env with your values

# Test deployment
./deploy_anvil.sh

# Production deployment
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Production deployment with verification
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
```
