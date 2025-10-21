#!/usr/bin/env node

import { encodeAbiParameters, parseAbiParameters, keccak256 } from 'viem';

/**
 * VaultV2 ABI Encoding Utilities
 *
 * Usage:
 *   yarn encode                                  # Interactive mode
 *   yarn encode adapter 0xABCD...                # Encode adapter ID
 *   yarn encode collateral 0xABCD...             # Encode collateral ID
 *   yarn encode market 0xABCD... 0x1234... ...   # Encode market ID
 */

// ============================================
// ID TYPES
// ============================================

interface MarketParams {
  loanToken: `0x${string}`;
  collateralToken: `0x${string}`;
  oracle: `0x${string}`;
  irm: `0x${string}`;
  lltv: bigint;
}

// ============================================
// ENCODING FUNCTIONS
// ============================================

/**
 * Encode adapter ID: abi.encode("this", adapterAddress)
 * Used for: adapter-level caps and allocations
 */
function encodeAdapterId(adapterAddress: `0x${string}`): {
  encoded: `0x${string}`;
  hash: `0x${string}`;
} {
  const encoded = encodeAbiParameters(
    parseAbiParameters('string, address'),
    ['this', adapterAddress]
  );

  const hash = keccak256(encoded);

  return { encoded, hash };
}

/**
 * Encode collateral ID: abi.encode("collateralToken", tokenAddress)
 * Used for: collateral-level caps across all markets
 */
function encodeCollateralId(tokenAddress: `0x${string}`): {
  encoded: `0x${string}`;
  hash: `0x${string}`;
} {
  const encoded = encodeAbiParameters(
    parseAbiParameters('string, address'),
    ['collateralToken', tokenAddress]
  );

  const hash = keccak256(encoded);

  return { encoded, hash };
}

/**
 * Encode market ID: abi.encode("this/marketParams", adapterAddress, marketParams)
 * Used for: market-specific caps and allocations
 */
function encodeMarketId(
  adapterAddress: `0x${string}`,
  marketParams: MarketParams
): {
  encoded: `0x${string}`;
  hash: `0x${string}`;
} {
  const encoded = encodeAbiParameters(
    parseAbiParameters('string, address, (address,address,address,address,uint256)'),
    [
      'this/marketParams',
      adapterAddress,
      [
        marketParams.loanToken,
        marketParams.collateralToken,
        marketParams.oracle,
        marketParams.irm,
        marketParams.lltv,
      ],
    ]
  );

  const hash = keccak256(encoded);

  return { encoded, hash };
}

/**
 * Encode MarketParams for allocate/deallocate data parameter
 * Used for: allocate(adapter, marketData, amount) where marketData = abi.encode(MarketParams)
 */
function encodeMarketParams(marketParams: MarketParams): `0x${string}` {
  return encodeAbiParameters(
    parseAbiParameters('(address,address,address,address,uint256)'),
    [
      [
        marketParams.loanToken,
        marketParams.collateralToken,
        marketParams.oracle,
        marketParams.irm,
        marketParams.lltv,
      ],
    ]
  );
}

// ============================================
// EXAMPLES
// ============================================

function printExamples() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  VaultV2 ABI Encoding Examples');
  console.log('═══════════════════════════════════════════════════════\n');

  // Example addresses from your deployment
  const vaultV1Adapter = '0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7';
  const marketAdapter = '0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600';
  const eulerAdapter = '0x98Cb0aB186F459E65936DB0C0E457F0D7d349c65';

  const cbBTC = '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf';
  const WETH = '0x4200000000000000000000000000000000000006';

  const market1: MarketParams = {
    loanToken: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', // USDC
    collateralToken: cbBTC,
    oracle: '0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9',
    irm: '0x46415998764c29aB2a25CbEA6254146D50D22687',
    lltv: 860000000000000000n, // 86%
  };

  console.log('1️⃣  ADAPTER ID (VaultV1)');
  console.log('───────────────────────────────────────────────────────');
  const adapterId = encodeAdapterId(vaultV1Adapter as `0x${string}`);
  console.log(`Address:  ${vaultV1Adapter}`);
  console.log(`Encoded:  ${adapterId.encoded}`);
  console.log(`Hash:     ${adapterId.hash}`);
  console.log('');

  console.log('2️⃣  ADAPTER ID (Euler ERC4626)');
  console.log('───────────────────────────────────────────────────────');
  const eulerAdapterId = encodeAdapterId(eulerAdapter as `0x${string}`);
  console.log(`Address:  ${eulerAdapter}`);
  console.log(`Encoded:  ${eulerAdapterId.encoded}`);
  console.log(`Hash:     ${eulerAdapterId.hash}`);
  console.log('');

  console.log('3️⃣  COLLATERAL ID (cbBTC)');
  console.log('───────────────────────────────────────────────────────');
  const collateralId = encodeCollateralId(cbBTC as `0x${string}`);
  console.log(`Address:  ${cbBTC}`);
  console.log(`Encoded:  ${collateralId.encoded}`);
  console.log(`Hash:     ${collateralId.hash}`);
  console.log('');

  console.log('4️⃣  MARKET ID (cbBTC/USDC Market)');
  console.log('───────────────────────────────────────────────────────');
  const marketId = encodeMarketId(marketAdapter as `0x${string}`, market1);
  console.log(`Adapter:  ${marketAdapter}`);
  console.log(`Market:   cbBTC/USDC (86% LTV)`);
  console.log(`Encoded:  ${marketId.encoded}`);
  console.log(`Hash:     ${marketId.hash}`);
  console.log('');

  console.log('5️⃣  MARKET PARAMS DATA (for allocate/deallocate)');
  console.log('───────────────────────────────────────────────────────');
  const marketData = encodeMarketParams(market1);
  console.log(`Market:   cbBTC/USDC (86% LTV)`);
  console.log(`Encoded:  ${marketData}`);
  console.log('');

  console.log('═══════════════════════════════════════════════════════\n');
}

// ============================================
// CLI INTERFACE
// ============================================

function printUsage() {
  console.log(`
VaultV2 ABI Encoder

USAGE:
  yarn encode                              Show examples
  yarn encode adapter <address>            Encode adapter ID
  yarn encode collateral <address>         Encode collateral ID
  yarn encode market <adapter> <params>    Encode market ID
  yarn encode market-data <params>         Encode market params for allocate

EXAMPLES:
  yarn encode adapter 0xAcd4fFdBABDc627e5474FA9d507Db1436CF65Cc7
  yarn encode collateral 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
  yarn encode market 0x26E2878CD6fC34BBFEBc7A3bD2C3BFd32a3b0600 \\
    0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \\
    0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf \\
    0x663BEcD10dAe6C4a3dCd89f1d76C1174199639B9 \\
    0x46415998764c29aB2a25CbEA6254146D50D22687 \\
    860000000000000000
`);
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    printExamples();
    return;
  }

  const command = args[0].toLowerCase();

  try {
    switch (command) {
      case 'adapter': {
        if (args.length !== 2) {
          console.error('❌ Usage: yarn encode adapter <address>');
          process.exit(1);
        }
        const address = args[1] as `0x${string}`;
        const result = encodeAdapterId(address);
        console.log('\n🔧 ADAPTER ID');
        console.log('─────────────────────────────────────────');
        console.log(`Input:    abi.encode("this", ${address})`);
        console.log(`Encoded:  ${result.encoded}`);
        console.log(`Hash ID:  ${result.hash}`);
        console.log('');
        break;
      }

      case 'collateral': {
        if (args.length !== 2) {
          console.error('❌ Usage: yarn encode collateral <address>');
          process.exit(1);
        }
        const address = args[1] as `0x${string}`;
        const result = encodeCollateralId(address);
        console.log('\n🪙 COLLATERAL ID');
        console.log('─────────────────────────────────────────');
        console.log(`Input:    abi.encode("collateralToken", ${address})`);
        console.log(`Encoded:  ${result.encoded}`);
        console.log(`Hash ID:  ${result.hash}`);
        console.log('');
        break;
      }

      case 'market': {
        if (args.length !== 7) {
          console.error('❌ Usage: yarn encode market <adapter> <loanToken> <collateralToken> <oracle> <irm> <lltv>');
          process.exit(1);
        }
        const adapter = args[1] as `0x${string}`;
        const marketParams: MarketParams = {
          loanToken: args[2] as `0x${string}`,
          collateralToken: args[3] as `0x${string}`,
          oracle: args[4] as `0x${string}`,
          irm: args[5] as `0x${string}`,
          lltv: BigInt(args[6]),
        };
        const result = encodeMarketId(adapter, marketParams);
        console.log('\n📊 MARKET ID');
        console.log('─────────────────────────────────────────');
        console.log(`Adapter:       ${adapter}`);
        console.log(`Loan Token:    ${marketParams.loanToken}`);
        console.log(`Collateral:    ${marketParams.collateralToken}`);
        console.log(`Oracle:        ${marketParams.oracle}`);
        console.log(`IRM:           ${marketParams.irm}`);
        console.log(`LLTV:          ${marketParams.lltv} (${Number(marketParams.lltv) / 1e18 * 100}%)`);
        console.log(`Encoded:       ${result.encoded}`);
        console.log(`Hash ID:       ${result.hash}`);
        console.log('');
        break;
      }

      case 'market-data': {
        if (args.length !== 6) {
          console.error('❌ Usage: yarn encode market-data <loanToken> <collateralToken> <oracle> <irm> <lltv>');
          process.exit(1);
        }
        const marketParams: MarketParams = {
          loanToken: args[1] as `0x${string}`,
          collateralToken: args[2] as `0x${string}`,
          oracle: args[3] as `0x${string}`,
          irm: args[4] as `0x${string}`,
          lltv: BigInt(args[5]),
        };
        const encoded = encodeMarketParams(marketParams);
        console.log('\n📦 MARKET DATA (for allocate/deallocate)');
        console.log('─────────────────────────────────────────');
        console.log(`Loan Token:    ${marketParams.loanToken}`);
        console.log(`Collateral:    ${marketParams.collateralToken}`);
        console.log(`Oracle:        ${marketParams.oracle}`);
        console.log(`IRM:           ${marketParams.irm}`);
        console.log(`LLTV:          ${marketParams.lltv} (${Number(marketParams.lltv) / 1e18 * 100}%)`);
        console.log(`Encoded:       ${encoded}`);
        console.log('');
        break;
      }

      case 'help':
      case '--help':
      case '-h':
        printUsage();
        break;

      default:
        console.error(`❌ Unknown command: ${command}`);
        printUsage();
        process.exit(1);
    }
  } catch (error) {
    console.error('❌ Error:', error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

main();
