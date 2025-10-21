// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {MorphoMarketV1AdapterFactory} from "vault-v2/adapters/MorphoMarketV1AdapterFactory.sol";
import {MorphoVaultV1AdapterFactory} from "vault-v2/adapters/MorphoVaultV1AdapterFactory.sol";
import {IMorphoMarketV1Adapter} from "vault-v2/adapters/interfaces/IMorphoMarketV1Adapter.sol";
import {IMorphoVaultV1Adapter} from "vault-v2/adapters/interfaces/IMorphoVaultV1Adapter.sol";
import {MarketParams} from "../lib/vault-v2/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title AllActions - Complete VaultV2 Operations Demo
 * @notice Demonstrates all 13 VaultV2 operations in a single script, organized by phase
 * @dev DEMO ONLY: Uses timelock = 0 for immediate execution
 *      Each action logs its calldata for manual Etherscan reproduction
 */
contract AllActions is Script {
    // Configuration
    struct Config {
        address vaultV2Factory;
        address marketV1AdapterFactory;
        address vaultV1AdapterFactory;
        address morpho;
        address vaultV1;
        address owner;
        address curator;
        address allocator;
        address sentinel;
        address asset;
        MarketParams market1;
        MarketParams market2;
    }

    // State
    VaultV2 public vault;
    address public adapter; // Single MarketV1 adapter for both markets
    address public vaultV1Adapter; // VaultV1 adapter for liquidity (deposit/withdraw)
    address public eulerVaultAdapter; // ERC4626 V1 Adapter for Euler vault
    address public tempCuratorAddress = address(0x1234567890123456789012345678901234567890);

    /**
     * @notice Main entry point - runs all phases
     */
    function run() external {
        Config memory config = _readConfig();

        console.log("====================================");
        console.log("    ALL ACTIONS DEMO - START");
        console.log("====================================");
        console.log("");

        vm.startBroadcast();

        // PHASE 0: Setup
        phase0_Setup(config);

        // PHASE 1: Building Portfolio
        phase1_BuildingPortfolio(config);

        // PHASE 2: Portfolio Operations
        phase2_PortfolioOperations(config);

        // PHASE 3: Risk Management
        phase3_RiskManagement(config);

        // PHASE 4: Emergency & Cleanup
        phase4_EmergencyAndCleanup(config);

        // BONUS: Add ERC4626 V1 Adapter for Euler Vault
        // addEulerVaultAdapter(config);

        vm.stopBroadcast();

        console.log("");
        console.log("====================================");
        console.log("    ALL ACTIONS DEMO - COMPLETE");
        console.log("====================================");
    }

    /**
     * PHASE 0: Setup - Deploy vault with timelock = 0
     * NOTE: Timelock must be 0 from deployment, or pre-configured before running this script
     */
    function phase0_Setup(Config memory config) internal {
        console.log(">>> PHASE 0: SETUP <<<");
        console.log("");

        // Deploy VaultV2 (owner will be tx.origin, which is the actual transaction originator/broadcaster)
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(config.vaultV2Factory).createVaultV2(tx.origin, config.asset, salt));

        console.log("[0.1] Vault deployed at:", address(vault));
        console.log("  Owner:", vault.owner());
        console.log("");

        // IMPORTANT: Vault must have timelock = 0 for all functions for this demo
        // This should be configured during deployment via DeployVaultV2.s.sol with TIMELOCK_DURATION=0
        // Or manually via owner calling decreaseTimelock and waiting
        console.log("[0.2] WARNING: This script assumes timelock = 0 for all functions");
        console.log("     Deploy vault with TIMELOCK_DURATION=0 or configure manually first");
        console.log("");

        // Set roles
        vault.setCurator(config.curator);

        // setIsAllocator requires timelock - submit + execute
        bytes memory setAllocatorData = abi.encodeCall(IVaultV2.setIsAllocator, (config.allocator, true));
        vault.submit(setAllocatorData);
        vault.setIsAllocator(config.allocator, true);

        vault.setIsSentinel(config.sentinel, true);

        console.log("[0.3] Roles configured:");
        console.log("  Curator:", config.curator);
        console.log("  Allocator:", config.allocator);
        console.log("  Sentinel:", config.sentinel);
        console.log("");

        // Deploy VaultV1 adapter for liquidity (deposit/withdraw flow)
        vaultV1Adapter = MorphoVaultV1AdapterFactory(config.vaultV1AdapterFactory)
            .createMorphoVaultV1Adapter(address(vault), config.vaultV1);
        console.log("[0.4] VaultV1 adapter deployed:", vaultV1Adapter);

        // Add VaultV1 adapter (submit + execute)
        bytes memory addVaultAdapterData = abi.encodeCall(IVaultV2.addAdapter, (vaultV1Adapter));
        vault.submit(addVaultAdapterData);
        vault.addAdapter(vaultV1Adapter);
        console.log("[0.5] VaultV1 adapter added to vault");

        // Set caps for VaultV1 adapter
        bytes memory vaultAdapterIdData = abi.encode("this", vaultV1Adapter);
        _setCaps(vaultAdapterIdData, "vault adapter", type(uint128).max, 1e18);

        // Set VaultV1 as liquidity adapter (for deposit/withdraw)
        vault.setLiquidityAdapterAndData(vaultV1Adapter, hex""); // Empty data for VaultV1Adapter
        console.log("[0.6] Liquidity adapter set to VaultV1 adapter");
        console.log("");

        // Approve and deposit USDC to vault
        uint256 depositAmount = 2e6; // 2 USDC (6 decimals)
        IERC20(config.asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, tx.origin);
        console.log("[0.7] Deposited", depositAmount, "USDC to vault");
        console.log("  Vault balance:", IERC20(config.asset).balanceOf(address(vault)));
        console.log("");
    }

    /**
     * Helper: Set timelock to 0 for all functions (demo only)
     * NOTE: This function is NOT called in the script because decreaseTimelock itself requires timelock
     * The vault MUST be deployed with timelock=0 from the start using DeployVaultV2.s.sol with TIMELOCK_DURATION=0
     * This function is kept for reference on which functions are timelocked
     */
    function _setTimelockToZeroReference() internal view {
        // Reference list of all timelocked function selectors
        bytes4[12] memory selectors = [
            IVaultV2.setReceiveSharesGate.selector,
            IVaultV2.setSendSharesGate.selector,
            IVaultV2.setReceiveAssetsGate.selector,
            IVaultV2.addAdapter.selector,
            IVaultV2.increaseAbsoluteCap.selector,
            IVaultV2.increaseRelativeCap.selector,
            IVaultV2.setForceDeallocatePenalty.selector,
            IVaultV2.abdicate.selector,
            IVaultV2.removeAdapter.selector,
            IVaultV2.increaseTimelock.selector,
            IVaultV2.setAdapterRegistry.selector,
            IVaultV2.setIsAllocator.selector
        ];

        // To actually set timelock to 0, the owner must:
        // 1. Call vault.decreaseTimelock(selector, 0) for each function
        // 2. Wait for the timelock period to elapse
        // 3. Call again to finalize
        // OR deploy with timelock=0 from the start
    }

    /**
     * PHASE 1: Building Portfolio
     * Actions: 1 (Add Token), 3 (Add Protocol), 10 (Restrict Tokens)
     */
    function phase1_BuildingPortfolio(Config memory config) internal {
        console.log(">>> PHASE 1: BUILDING PORTFOLIO <<<");
        console.log("");

        // ACTION 1: Add first token to portfolio (MarketV1)
        action1_AddTokenToPortfolio(config, config.market1, 1);

        // ACTION 3: Add second protocol/token (MarketV1)
        action3_AddProtocol(config, config.market2, 2);

        // ACTION 10: Demonstrate token restriction via caps
        action10_RestrictTokens();

        console.log("");
    }

    /**
     * ACTION 1: Add Token to Portfolio (Market 1)
     */
    function action1_AddTokenToPortfolio(Config memory config, MarketParams memory market, uint256 adapterNum)
        internal
    {
        console.log("--- ACTION 1: Add Token to Portfolio ---");

        // Step 1: Deploy adapter (one adapter for all markets)
        adapter = MorphoMarketV1AdapterFactory(config.marketV1AdapterFactory)
            .createMorphoMarketV1Adapter(address(vault), config.morpho);
        console.log("[1.1] Adapter deployed:", adapter);
        _logCalldata(
            "createMorphoMarketV1Adapter",
            abi.encodeCall(MorphoMarketV1AdapterFactory.createMorphoMarketV1Adapter, (address(vault), config.morpho))
        );

        // Step 2-4: Add adapter (submit + execute, timelock=0)
        bytes memory addAdapterData = abi.encodeCall(IVaultV2.addAdapter, (adapter));
        vault.submit(addAdapterData);
        console.log("[1.2] Submitted: addAdapter");
        _logCalldata("submit(addAdapter)", addAdapterData);

        vault.addAdapter(adapter);
        console.log("[1.3] Executed: addAdapter");
        _logCalldata("addAdapter", abi.encodeCall(IVaultV2.addAdapter, (adapter)));

        // Step 5: Set caps for adapter ID (shared by all markets)
        bytes memory adapterIdData = abi.encode("this", adapter);
        _setCaps(adapterIdData, "adapter", type(uint128).max, 1e18);

        // Step 6: Set caps for market 1 collateral ID
        bytes memory collateralIdData = abi.encode("collateralToken", market.collateralToken);
        _setCaps(collateralIdData, "collateral", type(uint128).max, 1e18);

        // Step 7: Set caps for market 1 ID
        bytes memory marketIdData = abi.encode("this/marketParams", adapter, market);
        _setCaps(marketIdData, "market", type(uint128).max, 1e18);

        console.log("[1.4] All caps set for market", adapterNum);
        console.log("");
    }

    /**
     * ACTION 3: Add Protocol (add second market to same adapter)
     */
    function action3_AddProtocol(Config memory config, MarketParams memory market, uint256 marketNum) internal {
        console.log("--- ACTION 3: Add Protocol (Second Market) ---");
        console.log("(MorphoMarketV1Adapter can handle multiple markets on same adapter)");

        // Same adapter handles both markets - just set caps for market 2
        console.log("[3.1] Using existing adapter:", adapter);

        // Set caps for market 2 collateral ID
        bytes memory collateralIdData = abi.encode("collateralToken", market.collateralToken);
        _setCaps(collateralIdData, "collateral (market 2)", type(uint128).max, 1e18);

        // Set caps for market 2 ID
        bytes memory marketIdData = abi.encode("this/marketParams", adapter, market);
        _setCaps(marketIdData, "market", type(uint128).max, 1e18);

        console.log("[3.2] All caps set for market", marketNum);
        console.log("");
    }

    /**
     * ACTION 10: Restrict Tokens (demonstrate cap adjustment)
     */
    function action10_RestrictTokens() internal {
        console.log("--- ACTION 10: Restrict Tokens ---");
        console.log("Demonstrating token restriction by adjusting caps");

        // Decrease absolute cap for adapter to 50% of max
        bytes memory adapterIdData = abi.encode("this", adapter);
        bytes32 adapterId = keccak256(adapterIdData);

        uint256 originalCap = vault.absoluteCap(adapterId);
        uint256 restrictedCap = originalCap / 2;

        bytes memory decreaseCapData = abi.encodeCall(IVaultV2.decreaseAbsoluteCap, (adapterIdData, restrictedCap));
        vault.decreaseAbsoluteCap(adapterIdData, restrictedCap);

        console.log("[10.1] Adapter 1 absolute cap decreased:");
        console.log("  From:", originalCap);
        console.log("  To:", restrictedCap);
        _logCalldata("decreaseAbsoluteCap", decreaseCapData);

        // Restore for demo continuity
        bytes memory increaseCapData = abi.encodeCall(IVaultV2.increaseAbsoluteCap, (adapterIdData, originalCap));
        vault.submit(increaseCapData);
        vault.increaseAbsoluteCap(adapterIdData, originalCap);
        console.log("[10.2] Cap restored to:", originalCap);
        console.log("");
    }

    /**
     * PHASE 2: Portfolio Operations
     * Actions: 5 (Rebalance), 12 (View Allocation), 13 (View History)
     */
    function phase2_PortfolioOperations(Config memory config) internal {
        console.log(">>> PHASE 2: PORTFOLIO OPERATIONS <<<");
        console.log("");

        // ACTION 7: Set liquidity adapter (REQUIRED before allocations)
        action7_SetLiquidityAdapter(config);

        // ACTION 5: Rebalance portfolio
        action5_Rebalance(config);

        // ACTION 12: View current allocation
        action12_ViewAllocation();

        // ACTION 13: View reallocation history
        action13_ViewHistory();

        console.log("");
    }

    /**
     * ACTION 7: Set Liquidity Adapter (Demonstrate Pause via Invalid Adapter)
     * NOTE: VaultV1 adapter was already set in phase0_Setup for deposit flow
     */
    function action7_SetLiquidityAdapter(Config memory config) internal {
        console.log("--- ACTION 7: Demonstrate Liquidity Adapter Configuration ---");
        console.log("(VaultV1 adapter already set in phase0_Setup)");
        console.log("Current liquidity adapter:", vaultV1Adapter);
        console.log("");
    }

    /**
     * ACTION 5: Rebalance Portfolio
     */
    function action5_Rebalance(Config memory config) internal {
        console.log("--- ACTION 5: Rebalance Portfolio ---");

        // First deallocate from VaultV1 adapter (where funds went during deposit)
        uint256 vaultAdapterAllocation = vault.allocation(keccak256(abi.encode("this", vaultV1Adapter)));
        uint256 availableAmount = 0;
        if (vaultAdapterAllocation > 0) {
            bytes memory deallocateVaultData =
                abi.encodeCall(IVaultV2.deallocate, (vaultV1Adapter, hex"", vaultAdapterAllocation));
            vault.deallocate(vaultV1Adapter, hex"", vaultAdapterAllocation);
            console.log("[5.0] Deallocated", vaultAdapterAllocation, "from VaultV1 adapter");
            _logCalldata("deallocate (from VaultV1)", deallocateVaultData);

            // Get actual balance after deallocation (may differ due to rounding)
            availableAmount = IERC20(config.asset).balanceOf(address(vault));
        } else {
            // If nothing to deallocate, use vault balance
            availableAmount = IERC20(config.asset).balanceOf(address(vault));
        }

        // Allocate to market 1 using available balance
        bytes memory market1Data = abi.encode(config.market1);
        bytes memory allocateData = abi.encodeCall(IVaultV2.allocate, (adapter, market1Data, availableAmount));

        vault.allocate(adapter, market1Data, availableAmount);
        console.log("[5.1] Allocated", availableAmount, "to market 1");
        _logCalldata("allocate", allocateData);

        // Deallocate half from market 1
        uint256 deallocateAmount = availableAmount / 2;
        bytes memory deallocateData = abi.encodeCall(IVaultV2.deallocate, (adapter, market1Data, deallocateAmount));

        vault.deallocate(adapter, market1Data, deallocateAmount);
        console.log("[5.2] Deallocated", deallocateAmount, "from market 1");
        _logCalldata("deallocate", deallocateData);

        // Allocate to market 2
        bytes memory market2Data = abi.encode(config.market2);
        bytes memory allocate2Data = abi.encodeCall(IVaultV2.allocate, (adapter, market2Data, deallocateAmount));

        vault.allocate(adapter, market2Data, deallocateAmount);
        console.log("[5.3] Allocated", deallocateAmount, "to market 2");
        _logCalldata("allocate", allocate2Data);
        console.log("");
    }

    /**
     * ACTION 12: View Current Allocation
     */
    function action12_ViewAllocation() internal {
        console.log("--- ACTION 12: View Current Allocation ---");

        uint256 adaptersCount = vault.adaptersLength();
        console.log("[12.1] Total adapters:", adaptersCount);

        for (uint256 i = 0; i < adaptersCount; i++) {
            address currentAdapter = vault.adapters(i);
            bytes32 adapterId = keccak256(abi.encode("this", currentAdapter));

            uint256 allocation = vault.allocation(adapterId);
            uint256 absoluteCap = vault.absoluteCap(adapterId);
            uint256 relativeCap = vault.relativeCap(adapterId);

            console.log("");
            console.log("Adapter", i + 1, ":", currentAdapter);
            console.log("  Allocation:", allocation);
            console.log("  Absolute Cap:", absoluteCap);
            console.log("  Relative Cap:", relativeCap, "(WAD)");

            // Get real assets from adapter
            try IMorphoMarketV1Adapter(currentAdapter).realAssets() returns (uint256 realAssets) {
                console.log("  Real Assets:", realAssets);
            } catch {
                console.log("  Real Assets: N/A");
            }
        }
        console.log("");
    }

    /**
     * ACTION 13: View Reallocation History
     */
    function action13_ViewHistory() internal {
        console.log("--- ACTION 13: View Reallocation History ---");
        console.log("To view history on Etherscan:");
        console.log("1. Go to:", address(vault));
        console.log("2. Navigate to Events tab");
        console.log("3. Filter for:");
        console.log("   - Allocate(sender, adapter, assets, ids, change)");
        console.log("   - Deallocate(sender, adapter, assets, ids, change)");
        console.log("   - ForceDeallocate(sender, adapter, assets, onBehalf, ids, penaltyAssets)");
        console.log("");
    }

    /**
     * PHASE 3: Risk Management
     * Actions: 9 (Restrict Protocols), 11 (Revoke Curator), 7/8 (Pause)
     */
    function phase3_RiskManagement(Config memory config) internal {
        console.log(">>> PHASE 3: RISK MANAGEMENT <<<");
        console.log("");

        // ACTION 9: Restrict protocols (adapter registry)
        action9_RestrictProtocols(config);

        // ACTION 11: Revoke curator rights
        action11_RevokeCurator(config);

        // ACTION 7/8: Pause deposits/withdrawals
        action7_8_PauseDepositsWithdrawals();

        console.log("");
    }

    /**
     * ACTION 9: Restrict Protocols (via adapter registry)
     */

    function action9_RestrictProtocols(Config memory config) internal {
        console.log("--- ACTION 9: Restrict Protocols ---");
        console.log("Setting adapter registry to restrict which adapters can be added");

        address dummyRegistry = address(0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a);

        bytes memory setRegistryData = abi.encodeCall(IVaultV2.setAdapterRegistry, (dummyRegistry));
        vault.submit(setRegistryData);
        vault.setAdapterRegistry(dummyRegistry);

        console.log("[9.1] Adapter registry set to:", dummyRegistry);
        _logCalldata("setAdapterRegistry", setRegistryData);
        console.log("");
    }

    /**
     * ACTION 11: Revoke Curator Rights
     */
    function action11_RevokeCurator(Config memory config) internal {
        console.log("--- ACTION 11: Revoke Curator Rights ---");

        // Demonstrate restriction: set curator to temp address
        bytes memory setCuratorData = abi.encodeCall(IVaultV2.setCurator, (tempCuratorAddress));
        vault.setCurator(tempCuratorAddress);
        console.log("[11.1] Curator temporarily set to:", tempCuratorAddress);
        _logCalldata("setCurator", setCuratorData);

        // Verify restriction
        address currentCurator = vault.curator();
        console.log("[11.2] Current curator:", currentCurator);

        // Restore for demo continuity
        vault.setCurator(config.curator);
        console.log("[11.3] Curator restored to:", config.curator);
        console.log("");
    }

    /**
     * ACTION 7 & 8: Pause Deposits/Withdrawals
     */
    function action7_8_PauseDepositsWithdrawals() internal {
        console.log("--- ACTION 7 & 8: Pause Deposits/Withdrawals ---");
        console.log("Using invalid liquidity adapter method");

        // Pause: set liquidity adapter to address(1)
        bytes memory pauseData = abi.encodeCall(IVaultV2.setLiquidityAdapterAndData, (address(1), hex""));
        vault.setLiquidityAdapterAndData(address(1), hex"");
        console.log("[7/8.1] Deposits/withdrawals PAUSED");
        console.log("  Liquidity adapter set to: address(1)");
        _logCalldata("setLiquidityAdapterAndData (pause)", pauseData);

        // Resume: set back to VaultV1 adapter (for deposit/withdraw)
        bytes memory resumeData = abi.encodeCall(IVaultV2.setLiquidityAdapterAndData, (vaultV1Adapter, hex""));
        vault.setLiquidityAdapterAndData(vaultV1Adapter, hex"");
        console.log("[7/8.2] Deposits/withdrawals RESUMED");
        console.log("  Liquidity adapter set to:", vaultV1Adapter);
        _logCalldata("setLiquidityAdapterAndData (resume)", resumeData);
        console.log("");
    }

    /**
     * PHASE 4: Emergency & Cleanup
     * Actions: 6 (Emergency Exit), 2 (Remove Token), 4 (Remove Protocol)
     */
    function phase4_EmergencyAndCleanup(Config memory config) internal {
        console.log(">>> PHASE 4: EMERGENCY & CLEANUP <<<");
        console.log("");

        // ACTION 6: Emergency exit
        action6_EmergencyExit(config);

        // ACTION 2: Remove token (Option A - decrease caps)
        action2_RemoveToken_OptionA(config);

        // ACTION 4: Remove protocol (Option B - remove adapter)
        action4_RemoveProtocol(config);

        console.log("");
    }

    /**
     * ACTION 6: Emergency Exit
     */
    function action6_EmergencyExit(Config memory config) internal {
        console.log("--- ACTION 6: Emergency Exit ---");
        console.log("Sentinel can execute without timelock");

        // Get adapter IDs
        bytes memory adapterIdData = abi.encode("this", adapter);
        bytes memory collateralIdData = abi.encode("collateralToken", config.market1.collateralToken);
        bytes memory marketIdData = abi.encode("this/marketParams", adapter, config.market1);

        // Step 1: Decrease all caps to zero
        vault.decreaseAbsoluteCap(adapterIdData, 0);
        vault.decreaseRelativeCap(adapterIdData, 0);
        console.log("[6.1] Adapter 1 caps set to zero");

        vault.decreaseAbsoluteCap(collateralIdData, 0);
        vault.decreaseRelativeCap(collateralIdData, 0);
        console.log("[6.2] Collateral caps set to zero");

        vault.decreaseAbsoluteCap(marketIdData, 0);
        vault.decreaseRelativeCap(marketIdData, 0);
        console.log("[6.3] Market caps set to zero");

        // Step 2: Deallocate all funds from all adapters (VaultV1, Market 1, Market 2)
        // Check VaultV1 adapter allocation
        bytes32 vaultV1AdapterId = keccak256(abi.encode("this", vaultV1Adapter));
        uint256 vaultV1Allocation = vault.allocation(vaultV1AdapterId);

        if (vaultV1Allocation > 0) {
            bytes memory deallocateVaultV1Data =
                abi.encodeCall(IVaultV2.deallocate, (vaultV1Adapter, hex"", vaultV1Allocation));
            vault.deallocate(vaultV1Adapter, hex"", vaultV1Allocation);
            console.log("[6.4] Deallocated from VaultV1 adapter:", vaultV1Allocation);
            _logCalldata("deallocate (emergency VaultV1)", deallocateVaultV1Data);
        }

        // Check market allocations
        bytes32 market1Id = keccak256(abi.encode("this/marketParams", adapter, config.market1));
        bytes32 market2Id = keccak256(abi.encode("this/marketParams", adapter, config.market2));

        uint256 market1Allocation = vault.allocation(market1Id);
        uint256 market2Allocation = vault.allocation(market2Id);

        if (market1Allocation > 0) {
            bytes memory market1Data = abi.encode(config.market1);
            bytes memory deallocateData1 =
                abi.encodeCall(IVaultV2.deallocate, (adapter, market1Data, market1Allocation));

            vault.deallocate(adapter, market1Data, market1Allocation);
            console.log("[6.5] Deallocated from market 1:", market1Allocation);
            _logCalldata("deallocate (emergency market 1)", deallocateData1);
        }

        if (market2Allocation > 0) {
            bytes memory market2Data = abi.encode(config.market2);
            bytes memory deallocateData2 =
                abi.encodeCall(IVaultV2.deallocate, (adapter, market2Data, market2Allocation));

            vault.deallocate(adapter, market2Data, market2Allocation);
            console.log("[6.6] Deallocated from market 2:", market2Allocation);
            _logCalldata("deallocate (emergency market 2)", deallocateData2);
        }

        if (vaultV1Allocation == 0 && market1Allocation == 0 && market2Allocation == 0) {
            console.log("[6.4] No funds to deallocate");
        }

        console.log("[6.7] Emergency exit complete");
        console.log("");
    }

    /**
     * ACTION 2: Remove Token (Option A - Decrease Caps)
     */
    function action2_RemoveToken_OptionA(Config memory config) internal {
        console.log("--- ACTION 2: Remove Token/Market (Option A) ---");
        console.log("Decrease market 2 caps to prevent new allocations");

        // Decrease caps for market 2 (already deallocated in emergency exit)
        bytes memory marketIdData = abi.encode("this/marketParams", adapter, config.market2);
        bytes32 marketId = keccak256(marketIdData);

        // Deallocate first if needed
        uint256 realAssets = IMorphoMarketV1Adapter(adapter).realAssets();
        if (realAssets > 0) {
            bytes memory marketData = abi.encode(config.market2);
            vault.deallocate(adapter, marketData, realAssets);
            console.log("[2.1] Deallocated", realAssets, "from market 2");
        }

        // Decrease market 2 caps to zero
        if (vault.absoluteCap(marketId) > 0) {
            vault.decreaseAbsoluteCap(marketIdData, 0);
            console.log("[2.2] Market 2 absolute cap set to zero");
        }

        if (vault.relativeCap(marketId) > 0) {
            vault.decreaseRelativeCap(marketIdData, 0);
            console.log("[2.3] Market 2 relative cap set to zero");
        }

        console.log("[2.4] Market 2 removal complete (adapter still active)");
        console.log("");
    }

    /**
     * ACTION 4: Remove Protocol (Option B - Remove Adapter)
     */
    function action4_RemoveProtocol(Config memory config) internal {
        console.log("--- ACTION 4: Remove Protocol (Option B) ---");
        console.log("Completely remove adapter from vault");

        // Ensure no allocation
        bytes32 adapterId = keccak256(abi.encode("this", adapter));
        uint256 allocation = vault.allocation(adapterId);
        console.log("[4.1] Adapter allocation:", allocation);

        if (allocation == 0) {
            // Remove adapter
            bytes memory removeAdapterData = abi.encodeCall(IVaultV2.removeAdapter, (adapter));
            vault.submit(removeAdapterData);
            vault.removeAdapter(adapter);

            console.log("[4.2] Adapter removed from vault");
            _logCalldata("removeAdapter", removeAdapterData);

            // Verify removal
            bool isAdapterCheck = vault.isAdapter(adapter);
            console.log("[4.3] isAdapter(adapter):", isAdapterCheck);
        } else {
            console.log("[4.2] Cannot remove: allocation not zero");
        }

        console.log("");
    }

    /**
     * BONUS: Add ERC4626 V1 Adapter for Euler Vault
     * Deploy and configure adapter for Euler vault at 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16
     */
    function addEulerVaultAdapter(Config memory config) internal {
        console.log(">>> BONUS: ADD EULER VAULT ADAPTER <<<");
        console.log("");

        // Euler vault address on Base
        address eulerVault = 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16;

        console.log("--- Adding ERC4626 V1 Adapter for Euler Vault ---");
        console.log("Euler Vault:", eulerVault);

        // Step 1: Deploy ERC4626 V1 Adapter using MorphoVaultV1AdapterFactory
        eulerVaultAdapter = MorphoVaultV1AdapterFactory(config.vaultV1AdapterFactory)
            .createMorphoVaultV1Adapter(address(vault), eulerVault);
        console.log("[E.1] Euler vault adapter deployed:", eulerVaultAdapter);
        _logCalldata(
            "createMorphoVaultV1Adapter",
            abi.encodeCall(MorphoVaultV1AdapterFactory.createMorphoVaultV1Adapter, (address(vault), eulerVault))
        );

        // Step 2: Add adapter (submit + execute)
        bytes memory addAdapterData = abi.encodeCall(IVaultV2.addAdapter, (eulerVaultAdapter));
        vault.submit(addAdapterData);
        console.log("[E.2] Submitted: addAdapter");
        _logCalldata("submit(addAdapter)", addAdapterData);

        vault.addAdapter(eulerVaultAdapter);
        console.log("[E.3] Executed: addAdapter");
        _logCalldata("addAdapter", abi.encodeCall(IVaultV2.addAdapter, (eulerVaultAdapter)));

        // Step 3: Set caps for Euler adapter
        bytes memory eulerAdapterIdData = abi.encode("this", eulerVaultAdapter);
        _setCaps(eulerAdapterIdData, "euler adapter", type(uint128).max, 1e18);

        console.log("[E.4] Euler vault adapter fully configured");
        console.log("");
    }

    /**
     * Helper: Set caps (submit + execute)
     */
    function _setCaps(bytes memory idData, string memory idType, uint256 absoluteCap, uint256 relativeCap) internal {
        // Absolute cap
        bytes memory increaseAbsoluteData = abi.encodeCall(IVaultV2.increaseAbsoluteCap, (idData, absoluteCap));
        vault.submit(increaseAbsoluteData);
        vault.increaseAbsoluteCap(idData, absoluteCap);

        // Relative cap
        bytes memory increaseRelativeData = abi.encodeCall(IVaultV2.increaseRelativeCap, (idData, relativeCap));
        vault.submit(increaseRelativeData);
        vault.increaseRelativeCap(idData, relativeCap);

        console.log("  Caps set for", idType, "ID:");
        console.log("    Absolute:", absoluteCap);
        console.log("    Relative:", relativeCap);
        _logCalldata(string(abi.encodePacked("increaseAbsoluteCap (", idType, ")")), increaseAbsoluteData);
        _logCalldata(string(abi.encodePacked("increaseRelativeCap (", idType, ")")), increaseRelativeData);
    }

    /**
     * Helper: Log calldata for Etherscan reproduction
     */
    function _logCalldata(string memory functionName, bytes memory data) internal view {
        console.log("  Calldata for", functionName, ":");
        console.log("    ");
        console.logBytes(data);
    }

    /**
     * Helper: Read configuration from environment
     */
    function _readConfig() internal view returns (Config memory config) {
        config.vaultV2Factory = vm.envAddress("VAULT_V2_FACTORY");
        config.marketV1AdapterFactory = vm.envAddress("MORPHO_MARKET_V1_ADAPTER_FACTORY");
        config.vaultV1AdapterFactory = vm.envAddress("MORPHO_VAULT_V1_ADAPTER_FACTORY");
        config.morpho = vm.envAddress("MORPHO_ADDRESS");
        config.vaultV1 = vm.envAddress("VAULT_V1");
        config.owner = vm.envAddress("OWNER");
        config.curator = vm.envAddress("CURATOR");
        config.allocator = vm.envAddress("ALLOCATOR");
        config.sentinel = vm.envAddress("SENTINEL");
        config.asset = vm.envAddress("ASSET");

        // Market 1
        config.market1 = MarketParams({
            loanToken: vm.envAddress("MARKET1_LOAN_TOKEN"),
            collateralToken: vm.envAddress("MARKET1_COLLATERAL_TOKEN"),
            oracle: vm.envAddress("MARKET1_ORACLE"),
            irm: vm.envAddress("MARKET1_IRM"),
            lltv: vm.envUint("MARKET1_LLTV")
        });

        // Market 2
        config.market2 = MarketParams({
            loanToken: vm.envAddress("MARKET2_LOAN_TOKEN"),
            collateralToken: vm.envAddress("MARKET2_COLLATERAL_TOKEN"),
            oracle: vm.envAddress("MARKET2_ORACLE"),
            irm: vm.envAddress("MARKET2_IRM"),
            lltv: vm.envUint("MARKET2_LLTV")
        });
    }
}
