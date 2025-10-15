# Morpho VaultV2 Deployment

> **⚠️ DISCLAIMER**: This repository is for educational purposes only. Use at your own risk. Test thoroughly before mainnet deployment.

## Overview

Deploy and configure Morpho VaultV2 instances with VaultV1 integration for automated liquidity management.

**What this does:**
- Creates a new VaultV2 instance
- Connects it to a VaultV1 for liquidity management
- Sets up roles, timelocks, and security configurations
- Handles dead deposit seeding (optional)

## Quick Start

### 1. Setup
```bash
git clone git@github.com:morpho-org/vault-v2-deployment.git
cd vault-v2-deployment
git submodule update --init --recursive
```

### 2. Configure Environment
Create `.env` file:
```bash
# Required: Role addresses
OWNER=0xYourOwnerAddress
CURATOR=0xYourCuratorAddress  
ALLOCATOR=0xYourAllocatorAddress
SENTINEL=0xYourSentinelAddress  # Optional

# Required: Contract addresses (Base Network examples)
VAULT_V1=0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A
ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a
VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857
MORPHO_VAULT_V1_ADAPTER_FACTORY=0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642

# Required: Deployment settings
RPC_URL=https://mainnet.base.org
PRIVATE_KEY=0xYourPrivateKey

# Optional: Timelock & verification
TIMELOCK_DURATION=1814400  # 21 days (0 for immediate)
ETHERSCAN_API_KEY=YourApiKey
```

### 3. Deploy
```bash
# Basic deployment
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# With contract verification
forge script script/DeployVaultV2.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify
```

## Testing

### Local Test Deployment
```bash
# Run test deployment on local Anvil
./deploy_anvil.sh
```

### Run Tests
```bash
# All tests
forge test

# Specific test
forge test --match-test test_DeadDeposit
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OWNER` | ✅ | Vault owner address |
| `CURATOR` | ✅ | Vault curator address |
| `ALLOCATOR` | ✅ | Vault allocator address |
| `SENTINEL` | ❌ | Sentinel address (optional) |
| `VAULT_V1` | ✅ | Source VaultV1 address |
| `ADAPTER_REGISTRY` | ✅ | Adapter registry address |
| `VAULT_V2_FACTORY` | ✅ | VaultV2 factory address |
| `MORPHO_VAULT_V1_ADAPTER_FACTORY` | ✅ | Adapter factory address |
| `RPC_URL` | ✅ | RPC endpoint URL |
| `PRIVATE_KEY` | ✅ | Deployment private key |
| `TIMELOCK_DURATION` | ❌ | Timelock duration in seconds |
| `ETHERSCAN_API_KEY` | ❌ | For contract verification |

## What Gets Deployed

The deployment script automatically:

1. **Creates VaultV2** via VaultV2Factory
2. **Deploys MorphoVaultV1Adapter** for VaultV1 integration
3. **Configures roles**: Owner, Curator, Allocator, Sentinel
4. **Sets up timelocks** for critical functions (if duration > 0)
5. **Configures adapter registry** and caps
6. **Executes dead deposit** (if amount specified)

## Advanced Features

### Dead Deposit
Add `DEAD_DEPOSIT_AMOUNT` to your `.env` to seed the vault with initial liquidity:
```bash
DEAD_DEPOSIT_AMOUNT=1000000000000000000000  # 1000 tokens
```

### Timelock Configuration
Functions with timelock protection:
- `setReceiveSharesGate`
- `setSendSharesGate` 
- `setReceiveAssetsGate`
- `addAdapter`
- `increaseAbsoluteCap`
- `increaseRelativeCap`
- `setForceDeallocatePenalty`
- `abdicate`
- `removeAdapter`
- `increaseTimelock`

## Documentation

- [VaultV2 Documentation](https://docs.morpho.org/learn/concepts/vault-v2/)
- [Build Your Own Script Guide](docs/build_own_script.md)
- [Contract Addresses](https://docs.morpho.org/get-started/resources/addresses/#morpho-v2-contracts)

## Security Notes

- **Never commit `.env` files** - they contain private keys
- **Test thoroughly** on testnets before mainnet
- **Verify all addresses** before deployment
- **Keep private keys secure** and use hardware wallets when possible

## Troubleshooting

### Common Issues
- **"No dead deposit provided"**: Set `DEAD_DEPOSIT_AMOUNT` in `.env`
- **"TransferFromReverted"**: Ensure sufficient token balance for dead deposit
- **"Invalid address"**: Verify all contract addresses are correct

### Getting Help
- Check the [Morpho Documentation](https://docs.morpho.org/)
- Review the test files for examples
- Ensure all environment variables are set correctly