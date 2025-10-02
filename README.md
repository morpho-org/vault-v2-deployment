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

This repository provides a comprehensive deployment solution for Morpho VaultV2 using a Morpho VaultV1 as an underlying liquidity market pool.

See VaultV2 deployment documentation [here](https://docs.morpho.org/learn/concepts/vault-v2/).

You can find a detailed explanation of the script, allowing you to build your own deployment script [here](docs/build_own_script.md).

The deployment process includes:

- **VaultV2 Factory**: Creates new VaultV2 instances
- **MorphoVaultV1 Adapter Factory**: Creates adapters for VaultV1 integration
- **VaultV2 Instance**: The main vault contract
- **MorphoVaultV1 Adapter**: Connects VaultV2 to VaultV1 for liquidity management

### Required Environment Variables

- `OWNER`: Address of the Owner role
- `CURATOR`: Address of the Curator role  
- `ALLOCATOR`: Address of an Allocator role
- `SENTINEL`: Address of a Sentinel role (optional)
- `VAULT_V1`: Address of the VaultV1 to use as liquidity market
- `ADAPTER_REGISTRY`: Address of the Adapter Registry
- `VAULT_V2_FACTORY`: Address of the VaultV2 Factory
- `MORPHO_VAULT_V1_ADAPTER_FACTORY`: Address of the MorphoVaultV1 Adapter Factory
- `RPC_URL`: Your RPC endpoint URL
- `PRIVATE_KEY`: Your private key for deployment (keep secure!)
- `TIMELOCK_DURATION`: Timelock duration in seconds (set to 0 for immediate execution)
- `ETHERSCAN_API_KEY`: Optional, for contract verification

**Note**: The underlying asset token is automatically inferred from the VaultV1 configuration.

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

Before deploying, you need to set up your environment variables. Create a `.env` file based on the following template:

#### Option 1: Using .env file (Recommended)

1. Create a `.env` file with the following template:
   ```bash
   # VaultV2 Deployment Environment Variables

   # Role addresses (replace with your actual addresses)
   OWNER=0xYourOwnerAddress
   CURATOR=0xYourCuratorAddress
   ALLOCATOR=0xYourAllocatorAddress
   SENTINEL=0xYourSentinelAddress

   # Timelock duration (in seconds) - set to 0 for immediate execution
   TIMELOCK_DURATION=1814400

   # Deployed contract addresses (Base Network addresses provided as examples)
   # @see https://docs.morpho.org/get-started/resources/addresses/#morpho-v2-contracts
   ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a
   VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857
   MORPHO_VAULT_V1_ADAPTER_FACTORY=0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642

   # Target Vault V1 (Base Network vault address provided as example)
   VAULT_V1=0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A

   # RPC URL for deployment
   RPC_URL=https://mainnet.base.org

   # Private key for deployment (keep secure!)
   PRIVATE_KEY=0xYourPrivateKeyHere

   # Optional: Etherscan API key for contract verification
   ETHERSCAN_API_KEY=YourEtherscanApiKeyHere
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
export ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a
export VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857
export MORPHO_VAULT_V1_ADAPTER_FACTORY=0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642
export TIMELOCK_DURATION=1814400
export RPC_URL=https://mainnet.base.org
export PRIVATE_KEY=0xYourPrivateKey
export ETHERSCAN_API_KEY=YourEtherscanApiKey
```

### 4. Deploy VaultV2

The deployment script creates a new VaultV2 instance and configures it to work with a VaultV1 as the liquidity market. The script handles:

- VaultV2 creation via the VaultV2Factory
- MorphoVaultV1Adapter deployment and configuration
- Role assignment and timelock configuration
- Adapter registry setup and caps configuration

Run the deployment script:

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
- Deploy mock contracts (ERC20Mock, ERC4626Mock, AdapterRegistryMock)
- Deploy factory contracts (VaultV2Factory, MorphoVaultV1AdapterFactory)
- Deploy the VaultV2 with test configuration
- Display deployment results and configuration
- Clean up and stop Anvil

**Note**: This is for testing only and uses temporary mock contracts. Do not use this for production deployments.

### Running Tests

The repository includes comprehensive tests:

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/DeployVaultV2.t.sol
```

### GitHub Actions Integration

The repository includes GitHub Actions workflows for automated testing:

- **CI Workflow** (`.github/workflows/test.yml`): Runs tests, formatting, and build checks
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
| `VAULT_V1` | ✅ | VaultV1 address to use | `0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A` |
| `ADAPTER_REGISTRY` | ✅ | Adapter Registry address | `0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a` |
| `VAULT_V2_FACTORY` | ✅ | VaultV2 Factory address | `0x4501125508079A99ebBebCE205DeC9593C2b5857` |
| `MORPHO_VAULT_V1_ADAPTER_FACTORY` | ✅ | MorphoVaultV1 Adapter Factory address | `0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642` |
| `RPC_URL` | ✅ | RPC endpoint URL | `https://mainnet.base.org` |
| `PRIVATE_KEY` | ✅ | Deployment private key | `0x2222...` |
| `TIMELOCK_DURATION` | ❌ | Timelock in seconds | `1814400` (21 days) |
| `ETHERSCAN_API_KEY` | ❌ | For contract verification | `abc123...` |

### Common Commands

```bash
# Setup
# Create .env file with your values (see environment variables section above)

# Install dependencies
git submodule update --init --recursive

# Test deployment
./deploy_anvil.sh

# Run tests
forge test

# Production deployment
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Production deployment with verification
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify

# Build contracts
forge build

# Format code
forge fmt
```
