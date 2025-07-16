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
- The **Automated Vic for Vault V1**

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

### 3. Deploy VaultV2

This script deploys a new VaultV2 instance and its related contracts to run with a VaultV1 as Liquidity Market.

Run the script:

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
export TIMELOCK_DURATION=TimelockDurationInSeconds
```

```bash
# Run the deployment script (without block explorer verification)
forge script script/DeployVaultV2.s.sol \
  --rpc-url <YOUR_RPC_URL> \
  --private-key <YOUR_PRIVATE_KEY> \
  --broadcast
```

```bash
# Run the deployment script (with verification on Etherscan)
# Refer to Foundry documentation for non Etherscan block explorers
forge script script/DeployVaultV2.s.sol \
  --rpc-url <YOUR_RPC_URL> \
  --private-key <YOUR_PRIVATE_KEY> \
  --broadcast \
  --etherscan-api-key <YOUR_ETHERSCAN_API_KEY> \
  --verify
```
