# VaultV2 TypeScript ABI Encoding Utilities

## Installation

```bash
yarn install
```

## Usage

### Show Examples
```bash
yarn encode
```

### Encode Adapter ID
```bash
# For VaultV1 adapter
yarn encode adapter 0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7

# For Euler ERC4626 adapter
yarn encode adapter 0x98Cb0aB186F459E65936DB0C0E457F0D7d349c65
```

**What this does:**
- Encodes: `abi.encode("this", adapterAddress)`
- Returns: encoded bytes + keccak256 hash (the ID used in vault)
- Used for: `absoluteCap(id)`, `relativeCap(id)`, `allocation(id)`

### Encode Collateral ID
```bash
# For cbBTC
yarn encode collateral 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf

# For WETH
yarn encode collateral 0x4200000000000000000000000000000000000006
```

**What this does:**
- Encodes: `abi.encode("collateralToken", tokenAddress)`
- Returns: encoded bytes + keccak256 hash
- Used for: Setting caps for a specific collateral across all markets

### Encode Market ID
```bash
yarn encode market \
  0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600 \
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf \
  0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9 \
  0x46415998764c29aB2a25CbEA6254146D50D22687 \
  860000000000000000
```

**Parameters:**
1. Adapter address
2. Loan token (USDC)
3. Collateral token (cbBTC)
4. Oracle address
5. IRM address
6. LLTV (86% = 860000000000000000)

**What this does:**
- Encodes: `abi.encode("this/marketParams", adapter, marketParams)`
- Returns: encoded bytes + keccak256 hash
- Used for: Setting caps for a specific market

### Encode Market Data (for allocate/deallocate)
```bash
yarn encode market-data \
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf \
  0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9 \
  0x46415998764c29aB2a25CbEA6254146D50D22687 \
  860000000000000000
```

**What this does:**
- Encodes: `abi.encode(MarketParams)`
- Returns: encoded bytes
- Used for: The `data` parameter in `allocate(adapter, data, amount)` and `deallocate(adapter, data, amount)`

## Quick Reference

### Your Deployed Adapters
- **VaultV1 (Morpho)**: `0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7`
- **MarketV1 (Morpho)**: `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600`
- **ERC4626 (Euler)**: `0x98Cb0aB186F459E65936DB0C0E457F0D7d349c65`

### Common Tokens on Base
- **USDC**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **cbBTC**: `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`
- **WETH**: `0x4200000000000000000000000000000000000006`

### Market Parameters (cbBTC/USDC 86%)
- Loan: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Collateral: `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`
- Oracle: `0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9`
- IRM: `0x46415998764c29aB2a25CbEA6254146D50D22687`
- LLTV: `860000000000000000`

### Market Parameters (WETH/USDC 86%)
- Loan: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Collateral: `0x4200000000000000000000000000000000000006`
- Oracle: `0xfEA2D58CEfCb9fcb597723C6BAe66FFe4193AFe4`
- IRM: `0x46415998764c29aB2a25CbEA6254146D50D22687`
- LLTV: `860000000000000000`

## Understanding the Output

When you run a command, you'll get:

```
Encoded:  0x00000000... (the ABI-encoded bytes)
Hash ID:  0xabcd...     (keccak256 of encoded bytes - this is the ID)
```

**The Hash ID is what you use in Solidity:**
- `vault.absoluteCap(hashId)`
- `vault.relativeCap(hashId)`
- `vault.allocation(hashId)`

**The Encoded bytes is what you use for:**
- `increaseAbsoluteCap(encoded, cap)`
- `increaseRelativeCap(encoded, cap)`
- `decreaseAbsoluteCap(encoded, cap)`
- `decreaseRelativeCap(encoded, cap)`
