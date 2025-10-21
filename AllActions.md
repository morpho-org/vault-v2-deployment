# AllActions.sol - Complete VaultV2 Operations Guide

## Deployed Vault Information

**Network:** Base Mainnet (Chain ID: 8453)
**Vault Address:** `0x8A7a3Cb46bca02491711275f5C837E23220539b0`
**Explorer:** https://basescan.org/address/0x8A7a3Cb46bca02491711275f5C837E23220539b0

---

## All 13 Actions - Implementation & Transaction Examples

This guide provides step-by-step instructions for reproducing each of the 13 VaultV2 operations on BaseScan, with actual transaction examples and calldata from the live deployment.

---

## Action 1: Add Token to Portfolio

**Purpose:** Deploy an adapter and add a new token/market to the portfolio with proper caps

**Steps Required:**

### Step 1.1: Deploy Morpho Market V1 Adapter
- **Contract:** MorphoMarketV1AdapterFactory (`0x133bac94306b99f6dad85c381a5be851d8dd717c`)
- **Function:** `createMorphoMarketV1Adapter(address vault, address morpho)`
- **Example TX:** [0x9aff81ccbd38bf2fc5749f2cced15d4fde7feaaeff5b24b3e0c2a96868a93fad](https://basescan.org/tx/0x9aff81ccbd38bf2fc5749f2cced15d4fde7feaaeff5b24b3e0c2a96868a93fad)
- **Result:** Deployed adapter at `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600`

### Step 1.2: Submit addAdapter via Timelock
- **Contract:** VaultV2 (`0x8A7a3Cb46bca02491711275f5C837E23220539b0`)
- **Function:** `submit(bytes data)`
- **Example TX:** [0x7acb1951471cfd3f46728afee0688a870cd11546ae4ee9e210af8a85da60463e](https://basescan.org/tx/0x7acb1951471cfd3f46728afee0688a870cd11546ae4ee9e210af8a85da60463e)
- **Calldata:**
```
0x60d54d4100000000000000000000000026e2878cd6fc34bbfebc7a3bd2c3bfd32a3b0600
```

### Step 1.3: Execute addAdapter
- **Contract:** VaultV2
- **Function:** `addAdapter(address adapter)`
- **Example TX:** [0x52e932b59aa68c0a47e337a200cc55e3b3c9f26b53bd92ab221b5518071b0d3b](https://basescan.org/tx/0x52e932b59aa68c0a47e337a200cc55e3b3c9f26b53bd92ab221b5518071b0d3b)
- **Arguments:**
  - `adapter`: `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600`

### Step 1.4: Set Caps for Adapter ID

**Submit increase absolute cap:**
- **Example TX:** [0x2f92c972e8161e01b65c606dc28cf99a8229dddcc8eeaae92a3b59bc6b29aa8e](https://basescan.org/tx/0x2f92c972e8161e01b65c606dc28cf99a8229dddcc8eeaae92a3b59bc6b29aa8e)
- **Calldata:**
```
0xf6f98fd5000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000ffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004000000000000000000000000026e2878cd6fc34bbfebc7a3bd2c3bfd32a3b060000000000000000000000000000000000000000000000000000000000000000047468697300000000000000000000000000000000000000000000000000000000
```

**Execute increase absolute cap:**
- **Function:** `increaseAbsoluteCap(bytes idData, uint256 cap)`
- **Example TX:** [0xeaa684d63192d7fb7490c7c8a8df261cb890af72036c33657979370aeae087e8](https://basescan.org/tx/0xeaa684d63192d7fb7490c7c8a8df261cb890af72036c33657979370aeae087e8)
- **Arguments:**
  - `idData`: `0x000000000000000000000000000000000000000000000000000000000000004000000000000000000000000026e2878cd6fc34bbfebc7a3bd2c3bfd32a3b060000000000000000000000000000000000000000000000000000000000000000047468697300000000000000000000000000000000000000000000000000000000`
  - `cap`: `340282366920938463463374607431768211455` (max uint128)

**Submit increase relative cap:**
- **Example TX:** [0x636a122c6568ed0e082021dc7fff9cf5a026de89c3cb5cdbfd67d49674583977](https://basescan.org/tx/0x636a122c6568ed0e082021dc7fff9cf5a026de89c3cb5cdbfd67d49674583977)

**Execute increase relative cap:**
- **Function:** `increaseRelativeCap(bytes idData, uint256 cap)`
- **Example TX:** [0xd48129c4fb119615173e7edbd6805ad8015e889cd48a66efcb9ce3caf6522538](https://basescan.org/tx/0xd48129c4fb119615173e7edbd6805ad8015e889cd48a66efcb9ce3caf6522538)
- **Arguments:**
  - `idData`: Same as absolute cap
  - `cap`: `1000000000000000000` (1e18 WAD = 100%)

### Step 1.5: Set Caps for Collateral ID

**Execute increase absolute cap for collateral:**
- **Example TX:** [0x33baa9520f6b2f3d6321ddba5cecee6b26015b9bfb88c6b996d2cd9c2e409e2f](https://basescan.org/tx/0x33baa9520f6b2f3d6321ddba5cecee6b26015b9bfb88c6b996d2cd9c2e409e2f)
- **Arguments:**
  - `idData`: `0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000cbb7c0000ab88b473b1f5afd9ef808440eed33bf000000000000000000000000000000000000000000000000000000000000000f636f6c6c61746572616c546f6b656e0000000000000000000000000000000000`
  - `cap`: `340282366920938463463374607431768211455`

**Execute increase relative cap for collateral:**
- **Example TX:** [0x650c2767befd4e4ce7b1002df72ca2a7a1d1809c64b26e167ceafe6f5477fbfa](https://basescan.org/tx/0x650c2767befd4e4ce7b1002df72ca2a7a1d1809c64b26e167ceafe6f5477fbfa)

### Step 1.6: Set Caps for Market ID

**Execute increase absolute cap for market:**
- **Example TX:** [0x7bd2f504499fa6263bd73ab571e6381a7333dbd8fcf7ee114ec4c7dc59d809b6](https://basescan.org/tx/0x7bd2f504499fa6263bd73ab571e6381a7333dbd8fcf7ee114ec4c7dc59d809b6)
- **Arguments:**
  - `idData`: Encoded market params (`this/marketParams`, adapter address, full MarketParams struct)
  - `cap`: `340282366920938463463374607431768211455`

**Execute increase relative cap for market:**
- **Example TX:** [0x7fd8428edf65457faee644b7f2e2e25dc1d1617f53ab062d34116018a53c1819](https://basescan.org/tx/0x7fd8428edf65457faee644b7f2e2e25dc1d1617f53ab062d34116018a53c1819)

**Implementation:** `action1_AddTokenToPortfolio` in script/AllActions.s.sol:201-235

---

## Action 2: Remove Token (Option A - Decrease Caps)

**Purpose:** Remove a token from portfolio by decreasing its caps to zero

**Steps Required:**

### Step 2.1: Deallocate All Funds (if any)
- **Function:** `deallocate(address adapter, bytes marketData, uint256 amount)`
- **Example TX (Market 1 deallocation):** [0xa32ff40325ddc163b6599df3e236b19ffaf2a5479f2ddf4fca1747a3bf569ba4](https://basescan.org/tx/0xa32ff40325ddc163b6599df3e236b19ffaf2a5479f2ddf4fca1747a3bf569ba4)
- **Example TX (Market 2 deallocation):** [0x4a4b405f98ca9df2a18a2ad32ab07865dccc5d45a6affe4d60151acb1ea09d34](https://basescan.org/tx/0x4a4b405f98ca9df2a18a2ad32ab07865dccc5d45a6affe4d60151acb1ea09d34)

### Step 2.2: Decrease Absolute Cap to 0
- **Function:** `decreaseAbsoluteCap(bytes idData, uint256 newCap)`
- **Example TX (Market 2):** [0x7a9f110fec79ac67f992dfddad20a36a6af886acdad0a619ae26bc3a6a1b98f0](https://basescan.org/tx/0x7a9f110fec79ac67f992dfddad20a36a6af886acdad0a619ae26bc3a6a1b98f0)
- **Arguments:**
  - `idData`: Market ID data (encoded market params)
  - `newCap`: `0`

### Step 2.3: Decrease Relative Cap to 0
- **Function:** `decreaseRelativeCap(bytes idData, uint256 newCap)`
- **Example TX (Market 2):** [0xdc3cfdbf2c3005aea436915940fd9dccdd09a5a62b7babf4648053fcc8dc0d51](https://basescan.org/tx/0xdc3cfdbf2c3005aea436915940fd9dccdd09a5a62b7babf4648053fcc8dc0d51)
- **Arguments:**
  - `idData`: Market ID data
  - `newCap`: `0`

**Note:** This method prevents new allocations but doesn't remove the adapter from the vault registry.

**Implementation:** `action2_RemoveToken_OptionA` in script/AllActions.s.sol:595-624

---

## Action 3: Add Protocol

**Purpose:** Add a new protocol (for Morpho, this means adding a new market to the same adapter)

**Steps Required:**

For MorphoMarketV1Adapter, one adapter can handle multiple markets. The process is the same as Action 1, but you only need to:

### Step 3.1: Set Caps for New Collateral Token (if different)
**Example TX (collateral cap for market 2):** [0xaa9a72a4b6d99cc4e47cb819c051f32398e9c1ffd09e1d95c51552af7cc36454](https://basescan.org/tx/0xaa9a72a4b6d99cc4e47cb819c051f32398e9c1ffd09e1d95c51552af7cc36454)

### Step 3.2: Set Caps for New Market ID
**Example TX (market 2 absolute cap):** [0x55a93201b5e2d409d69cba56faf6968fea72363489576f53d43bbb1d3fa552ad](https://basescan.org/tx/0x55a93201b5e2d409d69cba56faf6968fea72363489576f53d43bbb1d3fa552ad)
**Example TX (market 2 relative cap):** [0x82f89f57430259052e9a546be4bb5f9608881d0828968ff266db8e2515212692](https://basescan.org/tx/0x82f89f57430259052e9a546be4bb5f9608881d0828968ff266db8e2515212692)

**Implementation:** `action3_AddProtocol` in script/AllActions.s.sol:240-257

---

## Action 4: Remove Protocol (Option B - Remove Adapter)

**Purpose:** Completely remove an adapter from the vault

**Steps Required:**

### Step 4.1: Ensure Allocation = 0
Verify adapter has no funds allocated (via view functions or deallocate if needed)

### Step 4.2: Submit removeAdapter
- **Function:** `submit(bytes data)` where data = `removeAdapter(address adapter)`
- **Example TX:** [0x5d847112910dcd22e4a28a263c1c6b2dc4d85157c93897dc638c66c84f631a33](https://basescan.org/tx/0x5d847112910dcd22e4a28a263c1c6b2dc4d85157c93897dc638c66c84f631a33)
- **Calldata:**
```
0x585cd34b00000000000000000000000026e2878cd6fc34bbfebc7a3bd2c3bfd32a3b0600
```

### Step 4.3: Execute removeAdapter
- **Function:** `removeAdapter(address adapter)`
- **Example TX:** [0x6027cc5a37cbea3ad8cc178ea32dbb2cb45155d7f9f446fc7d1cb32a4993ff12](https://basescan.org/tx/0x6027cc5a37cbea3ad8cc178ea32dbb2cb45155d7f9f446fc7d1cb32a4993ff12)
- **Arguments:**
  - `adapter`: `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600`

### Step 4.4: Verify Removal
- **Function:** `isAdapter(address adapter)` (view function - no tx needed)
- Should return `false`

**Implementation:** `action4_RemoveProtocol` in script/AllActions.s.sol:629-655

---

## Action 5: Rebalance Portfolio

**Purpose:** Move funds between different adapters/markets

**Steps Required:**

### Step 5.1: Deallocate from Source Adapter
- **Function:** `deallocate(address adapter, bytes data, uint256 amount)`
- **Example TX (from VaultV1 adapter):** [0x6937e88f2c3e6dafbaf07cf6bf6a402d1ae0ec049ed0e0f3b53e55f640967749](https://basescan.org/tx/0x6937e88f2c3e6dafbaf07cf6bf6a402d1ae0ec049ed0e0f3b53e55f640967749)
- **Arguments:**
  - `adapter`: `0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7` (VaultV1 adapter)
  - `data`: `0x` (empty for VaultV1)
  - `amount`: `1999999` (USDC with 6 decimals)

### Step 5.2: Allocate to Target Market 1
- **Function:** `allocate(address adapter, bytes marketData, uint256 amount)`
- **Example TX:** [0x5c231014eb0ccc9bc8da8264ca052049573bddbd3c846bd15af860572a23e373](https://basescan.org/tx/0x5c231014eb0ccc9bc8da8264ca052049573bddbd3c846bd15af860572a23e373)
- **Arguments:**
  - `adapter`: `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600`
  - `marketData`: Encoded MarketParams struct
  - `amount`: `1999999`

### Step 5.3: Deallocate Partial from Market 1
- **Example TX:** [0x87de9b7af85225ef76f3c2ed9ca271092d8ecac24cdc169a075dc07213b3f5ff](https://basescan.org/tx/0x87de9b7af85225ef76f3c2ed9ca271092d8ecac24cdc169a075dc07213b3f5ff)

### Step 5.4: Allocate to Target Market 2
- **Example TX:** [0xca8b5d356f4c64dec5e6bc812c0fbc90bac1e481f0cbd6877abf51a3c7142b49](https://basescan.org/tx/0xca8b5d356f4c64dec5e6bc812c0fbc90bac1e481f0cbd6877abf51a3c7142b49)

**Note:** MarketParams encoding for allocate:
```solidity
bytes memory marketData = abi.encode(MarketParams({
    loanToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC
    collateralToken: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, // cbBTC
    oracle: 0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9,
    irm: 0x46415998764c29aB2a25CbEA6254146D50D22687,
    lltv: 860000000000000000 // 86%
}));
```

**Implementation:** `action5_Rebalance` in script/AllActions.s.sol:326-369

---

## Action 6: Emergency Exit

**Purpose:** Immediately exit all positions and set all caps to zero (Sentinel can execute without timelock)

**Steps Required:**

### Step 6.1: Decrease Adapter Caps to Zero
- **Function:** `decreaseAbsoluteCap(bytes idData, uint256 newCap)` & `decreaseRelativeCap(...)`
- **Example TX (adapter absolute):** [0x39cbce7f7c9ad22ce36d9704b14e701966f1fd7b837cf9b53256745be6481d3b](https://basescan.org/tx/0x39cbce7f7c9ad22ce36d9704b14e701966f1fd7b837cf9b53256745be6481d3b)
- **Example TX (adapter relative):** [0x7dbe7ede4fb693bc965143f6117bff690b6e0e0d226dced1c11dd13e0974bfc1](https://basescan.org/tx/0x7dbe7ede4fb693bc965143f6117bff690b6e0e0d226dced1c11dd13e0974bfc1)

### Step 6.2: Decrease Collateral Caps to Zero
- **Example TX (collateral absolute):** [0x5b8130225439a6414d4b72d786c9b92f477fce4f615404d0bfc08740637eb051](https://basescan.org/tx/0x5b8130225439a6414d4b72d786c9b92f477fce4f615404d0bfc08740637eb051)
- **Example TX (collateral relative):** [0x5a15e00b111142db58cce4dc7bc6ebecb4504a083c650962fa87d5f830741500](https://basescan.org/tx/0x5a15e00b111142db58cce4dc7bc6ebecb4504a083c650962fa87d5f830741500)

### Step 6.3: Decrease Market Caps to Zero
- **Example TX (market 1 absolute):** [0xfbf7f20f3eabb432e7c5c176dd7ca4bd6f176eb9b1e469b85b0e29b7606e0b3e](https://basescan.org/tx/0xfbf7f20f3eabb432e7c5c176dd7ca4bd6f176eb9b1e469b85b0e29b7606e0b3e)
- **Example TX (market 1 relative):** [0xd7d70ceca487823447390f20bbee9c59ce3283269d6b3b3c33a5ac1b6e2b5029](https://basescan.org/tx/0xd7d70ceca487823447390f20bbee9c59ce3283269d6b3b3c33a5ac1b6e2b5029)

### Step 6.4: Deallocate All Funds from All Adapters
- See Step 5 deallocate examples for transaction format

**Key Feature:** Sentinel role can execute this without timelock delay for emergency situations.

**Implementation:** `action6_EmergencyExit` in script/AllActions.s.sol:525-590

---

## Action 7: Pause Deposits

**Purpose:** Prevent new deposits into the vault

**Method Used:** Set liquidity adapter to invalid address (`address(1)`)

**Steps Required:**

### Step 7.1: Set Liquidity Adapter to Invalid Address
- **Function:** `setLiquidityAdapterAndData(address adapter, bytes data)`
- **Example TX (pause):** [0xa075a01b9830f23bc6d150fe73ad1da75d569382bc673caebcdfa28f1819c5e1](https://basescan.org/tx/0xa075a01b9830f23bc6d150fe73ad1da75d569382bc673caebcdfa28f1819c5e1)
- **Arguments:**
  - `adapter`: `0x0000000000000000000000000000000000000001` (address(1))
  - `data`: `0x` (empty)

### Step 7.2: Resume Deposits (set back to valid adapter)
- **Example TX (resume):** [0x0ea09c79bb9a99ec5073939d6479a842a46c17b84d98f706b85f543d6b7a7ce8](https://basescan.org/tx/0x0ea09c79bb9a99ec5073939d6479a842a46c17b84d98f706b85f543d6b7a7ce8)
- **Arguments:**
  - `adapter`: `0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7` (VaultV1 adapter)
  - `data`: `0x`

**Note:** This method blocks both deposits AND withdrawals.

**Implementation:** `action7_8_PauseDepositsWithdrawals` in script/AllActions.s.sol:482-500

---

## Action 8: Pause Withdrawals

**Purpose:** Prevent withdrawals from the vault

**Method Used:** Same as Action 7 (setting liquidity adapter to `address(1)` blocks both deposits and withdrawals)

**See Action 7 for transaction examples.**

**Implementation:** `action7_8_PauseDepositsWithdrawals` in script/AllActions.s.sol:482-500

---

## Action 9: Restrict Protocols

**Purpose:** Restrict which adapters can be added to the vault via adapter registry

**Steps Required:**

### Step 9.1: Submit setAdapterRegistry
- **Function:** `submit(bytes data)` where data = `setAdapterRegistry(address registry)`
- **Example TX:** [0xa1947be7b99bfc061f9ad5dfc45a3629748bf0bb6a581bfb123818166288029a](https://basescan.org/tx/0xa1947be7b99bfc061f9ad5dfc45a3629748bf0bb6a581bfb123818166288029a)
- **Calldata:**
```
0x5b34b8230000000000000000000000005c2531cbd2cf112cf687da3cd536708add7db10a
```

### Step 9.2: Execute setAdapterRegistry
- **Function:** `setAdapterRegistry(address registry)`
- **Example TX:** [0x396bf81e4ab132a0489ea8c1ea3a8cb49e4fcd1529004cfb554eebe342ba6cb7](https://basescan.org/tx/0x396bf81e4ab132a0489ea8c1ea3a8cb49e4fcd1529004cfb554eebe342ba6cb7)
- **Arguments:**
  - `registry`: `0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a` (dummy registry address)

**Implementation:** `action9_RestrictProtocols` in script/AllActions.s.sol:442-455

---

## Action 10: Restrict Tokens

**Purpose:** Limit exposure to specific tokens by adjusting caps

**Steps Required:**

### Step 10.1: Decrease Absolute Cap
- **Function:** `decreaseAbsoluteCap(bytes idData, uint256 newCap)`
- **Example TX:** [0xc0775c0d3e6eac7776a5d568151424ee2cf1a52471053b0f2d9c89b507c7c0bf](https://basescan.org/tx/0xc0775c0d3e6eac7776a5d568151424ee2cf1a52471053b0f2d9c89b507c7c0bf)
- **Arguments:**
  - `idData`: Adapter ID data (`this`, adapter address)
  - `newCap`: `170141183460469231731687303715884105727` (50% of max)

### Step 10.2: Restore Cap (for demo continuity)
- **Submit increase:** [0x1c1035ecb961bf80df538e9b2f0dfe0c0bc0bbd8deb2e4e149f97f2edfe8ded9](https://basescan.org/tx/0x1c1035ecb961bf80df538e9b2f0dfe0c0bc0bbd8deb2e4e149f97f2edfe8ded9)
- **Execute increase:** [0x386530ee03ab0e0dac8a0d7e380803e26df9399443934593acf5c7001c758091](https://basescan.org/tx/0x386530ee03ab0e0dac8a0d7e380803e26df9399443934593acf5c7001c758091)

**Implementation:** `action10_RestrictTokens` in script/AllActions.s.sol:262-287

---

## Action 11: Revoke Curator Rights

**Purpose:** Remove curator privileges from current curator address

**Steps Required:**

### Step 11.1: Set Curator to New Address (or zero address to revoke)
- **Function:** `setCurator(address newCurator)`
- **Example TX (revoke - set to temp address):** [0x30e7825ec1500c52d32ece38b2eb9cf72f01ede017bd1ea6f5cc4995b7adc975](https://basescan.org/tx/0x30e7825ec1500c52d32ece38b2eb9cf72f01ede017bd1ea6f5cc4995b7adc975)
- **Arguments:**
  - `newCurator`: `0x1234567890123456789012345678901234567890` (temp address)

### Step 11.2: Restore Curator (for demo continuity)
- **Example TX:** [0x4178d50cf0d937f04dcd1d63c0e74a071c640ced1bb11f0eae896099725b32f9](https://basescan.org/tx/0x4178d50cf0d937f04dcd1d63c0e74a071c640ced1bb11f0eae896099725b32f9)
- **Arguments:**
  - `newCurator`: `0x7f7A70b5B584C4033CAfD52219a496Df9AFb1af7` (original curator)

**Implementation:** `action11_RevokeCurator` in script/AllActions.s.sol:460-477

---

## Action 12: View Current Allocation

**Purpose:** View all current allocations across all adapters

**Method:** Read-only view functions (no transactions required)

**Functions to Call:**

1. `adaptersLength()` - Get total number of adapters
2. `adapters(uint256 index)` - Get adapter address at index
3. `allocation(bytes32 id)` - Get current allocation for an ID
4. `absoluteCap(bytes32 id)` - Get absolute cap for an ID
5. `relativeCap(bytes32 id)` - Get relative cap for an ID
6. Call `realAssets()` on each adapter to get actual deployed amounts

**ID Calculation:**
```solidity
bytes32 adapterId = keccak256(abi.encode("this", adapterAddress));
bytes32 collateralId = keccak256(abi.encode("collateralToken", tokenAddress));
bytes32 marketId = keccak256(abi.encode("this/marketParams", adapterAddress, marketParams));
```

**Example Output (from script logs):**
```
Adapter 1: 0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7
  Allocation: 0
  Absolute Cap: 340282366920938463463374607431768211455
  Relative Cap: 1000000000000000000 (100%)

Adapter 2: 0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600
  Allocation: 999999 (approx, varies based on rebalancing)
  Absolute Cap: 340282366920938463463374607431768211455
  Relative Cap: 1000000000000000000 (100%)
```

**Implementation:** `action12_ViewAllocation` in script/AllActions.s.sol:374-402

---

## Action 13: View Reallocation History

**Purpose:** View historical allocation/deallocation events

**Method:** View on BaseScan Events Tab

**Steps:**

1. Go to vault address: https://basescan.org/address/0x8A7a3Cb46bca02491711275f5C837E23220539b0#events
2. Filter for these events:
   - `Allocate(address indexed sender, address indexed adapter, uint256 assets, bytes[] ids, int256 change)`
   - `Deallocate(address indexed sender, address indexed adapter, uint256 assets, bytes[] ids, int256 change)`
   - `ForceDeallocate(address indexed sender, address indexed adapter, uint256 assets, address indexed onBehalf, bytes[] ids, uint256 penaltyAssets)`

**Example Allocate Event:**
- TX: [0x5c231014eb0ccc9bc8da8264ca052049573bddbd3c846bd15af860572a23e373](https://basescan.org/tx/0x5c231014eb0ccc9bc8da8264ca052049573bddbd3c846bd15af860572a23e373)

**Example Deallocate Event:**
- TX: [0x6937e88f2c3e6dafbaf07cf6bf6a402d1ae0ec049ed0e0f3b53e55f640967749](https://basescan.org/tx/0x6937e88f2c3e6dafbaf07cf6bf6a402d1ae0ec049ed0e0f3b53e55f640967749)

**Implementation:** `action13_ViewHistory` in script/AllActions.s.sol:407-417

---

## Summary of Contract Addresses

| Component | Address | Purpose |
|-----------|---------|---------|
| VaultV2 | `0x8A7a3Cb46bca02491711275f5C837E23220539b0` | Main vault contract |
| VaultV2 Factory | `0x4501125508079a99ebbeBce205dec9593c2b5857` | Factory for deploying vaults |
| MorphoMarketV1 Adapter | `0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600` | Adapter for Morpho markets |
| MorphoVaultV1 Adapter | `0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7` | Adapter for liquidity (deposit/withdraw) |
| MarketV1 Adapter Factory | `0x133bac94306b99f6dad85c381a5be851d8dd717c` | Factory for market adapters |
| VaultV1 Adapter Factory | `0xf42d9c36b34c9c2cf3bc30ed2a52a90eeb604642` | Factory for vault adapters |

---

## Key Configuration Parameters

**Markets Used:**

**Market 1 (cbBTC/USDC):**
- Loan Token: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (USDC)
- Collateral Token: `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` (cbBTC)
- Oracle: `0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9`
- IRM: `0x46415998764c29aB2a25CbEA6254146D50D22687`
- LLTV: `860000000000000000` (86%)

**Market 2 (WETH/USDC):**
- Loan Token: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (USDC)
- Collateral Token: `0x4200000000000000000000000000000000000006` (WETH)
- Oracle: `0xfEA2D58CEfCb9fcb597723C6BAe66FFe4193AFe4`
- IRM: `0x46415998764c29aB2a25CbEA6254146D50D22687`
- LLTV: `860000000000000000` (86%)

---

## Important Notes

### Timelock = 0 Requirement

This deployment uses **timelock = 0** for demo purposes only. This allows immediate execution of timelocked functions without waiting.

**NEVER use timelock = 0 in production!** Production vaults should use 21+ days timelock for security.

**Timelocked Functions:**
- `addAdapter`
- `removeAdapter`
- `increaseAbsoluteCap`
- `increaseRelativeCap`
- `setAdapterRegistry`
- `setIsAllocator`
- `setReceiveSharesGate`
- `setSendSharesGate`
- `setReceiveAssetsGate`
- `setForceDeallocatePenalty`
- `increaseTimelock`
- `abdicate`

### How to Use This Guide

1. **To reproduce any action on BaseScan:**
   - Navigate to the vault contract page
   - Go to "Write Contract" tab
   - Connect your wallet (must have appropriate role)
   - Find the function name from the action
   - Copy the arguments from the examples
   - Execute the transaction

2. **To view historical data:**
   - Navigate to vault contract page
   - Go to "Read Contract" tab for current state
   - Go to "Events" tab for historical actions

3. **To create new actions:**
   - Use the calldata examples as templates
   - Modify addresses and parameters for your use case
   - Submit via timelock if required
   - Execute after timelock period

---

## Testing Status

**Deployment:** Successfully deployed on Base mainnet
**Actions Completed:** 13/13
**Allocation/Deallocation:** Successfully demonstrated (may have minor rounding variations)

---

## Source Code

Full implementation: `script/AllActions.s.sol`

To run locally:
```bash
export TIMELOCK_DURATION=0 && \
  export VAULT_V2_FACTORY=0x4501125508079A99ebBebCE205DeC9593C2b5857 && \
  export MORPHO_MARKET_V1_ADAPTER_FACTORY=0x133baC94306B99f6dAD85c381a5be851d8DD717c && \
  export MORPHO_VAULT_V1_ADAPTER_FACTORY=0xF42D9c36b34c9c2CF3Bc30eD2a52a90eEB604642 && \
  export MORPHO_ADDRESS=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb && \
  export VAULT_V1=0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183 && \
  export ADAPTER_REGISTRY=0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a && \
  export OWNER=0x_MyAddress && \
  export CURATOR=0x_MyAddress && \
  export ALLOCATOR=0x_MyAddress && \
  export SENTINEL=0x_MyAddress && \
  export ASSET=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 && \
  export MARKET1_LOAN_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 && \
  export MARKET1_COLLATERAL_TOKEN=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf && \
  export MARKET1_ORACLE=0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9 && \
  export MARKET1_IRM=0x46415998764C29aB2a25CbeA6254146D50D22687 && \
  export MARKET1_LLTV=860000000000000000 && \
  export MARKET2_LOAN_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 && \
  export MARKET2_COLLATERAL_TOKEN=0x4200000000000000000000000000000000000006 && \
  export MARKET2_ORACLE=0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4 && \
  export MARKET2_IRM=0x46415998764C29aB2a25CbeA6254146D50D22687 && \
  export MARKET2_LLTV=860000000000000000 && \
  export PRIVATE_KEY=XXX && \
  forge script script/AllActions.s.sol --rpc-url https://base-mainnet.g.alchemy.com/v2/XXX --broadcast --private-key $PRIVATE_KEY -vvv | tee output.log
```

---

**Document Version:** 2.0
**Last Updated:** From broadcast file run-latest.json
**Network:** Base Mainnet (Chain ID 8453)
