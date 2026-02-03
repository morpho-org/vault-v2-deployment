// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {IMorphoMarketV1AdapterV2} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2.sol";
import {IMorphoMarketV1AdapterV2Factory} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2Factory.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMorpho, MarketParams, Id, Position} from "morpho-blue/src/interfaces/IMorpho.sol";

/**
 * @title DeployVaultV2WithMarketAdapter
 * @notice Deployment script for VaultV2 with MorphoMarketV1AdapterV2 (direct Morpho Blue market access)
 * @dev This script deploys a VaultV2 that connects directly to Morpho Blue markets,
 *      bypassing MetaMorpho (Vault V1). Use this when you want direct market access.
 *
 *      Key differences from DeployVaultV2.s.sol (which uses MorphoVaultV1Adapter):
 *      - No Vault V1 (MetaMorpho) required
 *      - Direct access to Morpho Blue markets
 *      - 3-level cap structure: adapter → collateral token → market params
 *      - Adapter has its own independent timelock system
 *      - Markets must have dead deposits (1e9 shares to 0xdead) before use
 *
 *      After deployment, you must configure market caps for each market you want to use.
 *      See docs/build_own_script.md for market configuration details.
 *
 *      ============================================================================
 *      MORPHO LISTING REQUIREMENT: Naming Restriction
 *      ============================================================================
 *      The vault's name and symbol CANNOT contain the word "morpho" (case insensitive).
 *
 *      This is validated during the listing process, not by this script.
 *      When creating your vault, ensure you choose a name/symbol that does NOT include:
 *      - "morpho", "Morpho", "MORPHO", etc.
 *
 *      Example valid names: "My USDC Vault", "Blue Chip Yield"
 *      Example invalid names: "Morpho USDC Vault", "My MorphoVault"
 *      ============================================================================
 *
 *      ============================================================================
 *      DEPLOYMENT PHASES OVERVIEW
 *      ============================================================================
 *      Phase 1:  Deploy VaultV2 instance via factory
 *      Phase 2:  Configure temporary permissions for deployment
 *      Phase 3:  Deploy MorphoMarketV1AdapterV2 via factory
 *      Phase 4:  Submit timelocked configuration changes
 *      Phase 5:  Execute immediate configuration changes + abdications
 *      Phase 6:  Set final role assignments (owner, curator, sentinel)
 *      Phase 7:  Configure market and liquidity adapter (if MARKET_ID provided)
 *      Phase 8:  Execute vault dead deposit (inflation attack protection)
 *      Phase 9:  Configure vault timelocks (LISTING REQUIREMENT)
 *      Phase 10: Configure adapter timelocks (LISTING REQUIREMENT)
 *      ============================================================================
 */
contract DeployVaultV2WithMarketAdapter is Script {
    uint256 constant DEAD_DEPOSIT_HIGH_DECIMALS = 1e9; // For assets with >= 10 decimals
    uint256 constant DEAD_DEPOSIT_LOW_DECIMALS = 1e12; // For assets with <= 9 decimals
    uint8 constant DECIMALS_THRESHOLD = 10;

    /**
     * @notice Configuration struct for deployment parameters
     * @dev Each field serves a specific purpose in the deployment:
     *
     *      ROLE ADDRESSES:
     *      - vaultOwner: Final owner after deployment, has full administrative control
     *      - vaultCurator: Can manage vault parameters (caps, markets, etc.)
     *      - vaultAllocator: Can allocate/deallocate funds between adapters
     *      - vaultSentinel: Emergency role for protective actions (optional)
     *
     *      INFRASTRUCTURE:
     *      - asset: The underlying ERC20 token the vault accepts (e.g., USDC, WETH)
     *      - adapterRegistry: Morpho's registry that validates adapters
     *      - vaultV2FactoryAddress: Factory contract for creating VaultV2 instances
     *      - morphoMarketAdapterFactoryAddress: Factory for MorphoMarketV1AdapterV2
     *
     *      FIRST MARKET (OPTIONAL):
     *      - marketId: Morpho Blue market ID (bytes32(0) to skip market setup)
     *      - collateralTokenCap: Maximum allocation to this collateral token
     *      - marketCap: Maximum allocation to this specific market
     *
     *      TIMELOCKS (MORPHO LISTING REQUIREMENT):
     *      - vaultTimelockDuration: Timelock for vault functions (minimum 3 days for listing)
     *      - adapterTimelockDuration: Timelock for adapter functions (minimum 3 days for listing)
     */
    struct DeploymentConfig {
        address vaultOwner;
        address vaultCurator;
        address vaultAllocator;
        address vaultSentinel;
        address asset;
        address adapterRegistry;
        address vaultV2FactoryAddress;
        address morphoMarketAdapterFactoryAddress;
        // First market configuration (optional - set marketId to bytes32(0) to skip)
        bytes32 marketId;
        uint128 collateralTokenCap;
        uint128 marketCap;
        // Timelock configuration (MORPHO LISTING REQUIREMENT)
        // Set to 0 to skip timelocks (vault will NOT meet listing requirements)
        uint256 vaultTimelockDuration;
        uint256 adapterTimelockDuration;
    }

    /**
     * @notice Main deployment function that reads configuration from environment variables
     * @return vaultV2Address The address of the deployed VaultV2 instance
     */
    function run() external returns (address) {
        DeploymentConfig memory config = _readEnvironmentConfig();
        return deployVaultV2WithConfig(config);
    }

    /**
     * @notice Deploy VaultV2 with explicit configuration parameters
     * @param vaultOwner Address that will own the vault after deployment
     * @param vaultCurator Address that can manage vault parameters
     * @param vaultAllocator Address that can allocate funds to adapters
     * @param vaultSentinel Address that can perform emergency actions (optional)
     * @param asset The underlying asset token address
     * @param adapterRegistry Address of the adapter registry
     * @param vaultV2FactoryAddress Address of the VaultV2 factory
     * @param morphoMarketAdapterFactoryAddress Address of the MorphoMarketV1AdapterV2 factory
     * @param marketId Morpho Blue market ID for first market (bytes32(0) to skip market setup)
     * @param collateralTokenCap Absolute cap for collateral token level
     * @param marketCap Absolute cap for market level
     * @param vaultTimelockDuration Timelock duration for vault functions (0 to skip)
     * @param adapterTimelockDuration Timelock duration for adapter functions (0 to skip)
     * @return vaultV2Address The address of the deployed VaultV2 instance
     */
    function runWithArguments(
        address vaultOwner,
        address vaultCurator,
        address vaultAllocator,
        address vaultSentinel,
        address asset,
        address adapterRegistry,
        address vaultV2FactoryAddress,
        address morphoMarketAdapterFactoryAddress,
        bytes32 marketId,
        uint128 collateralTokenCap,
        uint128 marketCap,
        uint256 vaultTimelockDuration,
        uint256 adapterTimelockDuration
    ) public returns (address) {
        DeploymentConfig memory config = DeploymentConfig({
            vaultOwner: vaultOwner,
            vaultCurator: vaultCurator,
            vaultAllocator: vaultAllocator,
            vaultSentinel: vaultSentinel,
            asset: asset,
            adapterRegistry: adapterRegistry,
            vaultV2FactoryAddress: vaultV2FactoryAddress,
            morphoMarketAdapterFactoryAddress: morphoMarketAdapterFactoryAddress,
            marketId: marketId,
            collateralTokenCap: collateralTokenCap,
            marketCap: marketCap,
            vaultTimelockDuration: vaultTimelockDuration,
            adapterTimelockDuration: adapterTimelockDuration
        });

        return deployVaultV2WithConfig(config);
    }

    /**
     * @notice Read configuration from environment variables
     * @return config Deployment configuration struct
     * @dev Environment variables:
     *      Required: OWNER, ASSET, ADAPTER_REGISTRY, VAULT_V2_FACTORY, MORPHO_MARKET_V1_ADAPTER_V2_FACTORY
     *      Optional: CURATOR, ALLOCATOR, SENTINEL (defaults to OWNER or address(0))
     *      Market: MARKET_ID, COLLATERAL_TOKEN_CAP, MARKET_CAP (set MARKET_ID=0x0 to skip)
     *      Timelocks: VAULT_TIMELOCK_DURATION, ADAPTER_TIMELOCK_DURATION (in seconds, 0 to skip)
     */
    function _readEnvironmentConfig() internal view returns (DeploymentConfig memory config) {
        config.vaultOwner = vm.envAddress("OWNER");
        config.vaultCurator = vm.envOr("CURATOR", config.vaultOwner);
        config.vaultAllocator = vm.envOr("ALLOCATOR", config.vaultOwner);
        config.vaultSentinel = vm.envOr("SENTINEL", address(0));
        config.asset = vm.envAddress("ASSET");
        config.adapterRegistry = vm.envAddress("ADAPTER_REGISTRY");
        config.vaultV2FactoryAddress = vm.envAddress("VAULT_V2_FACTORY");
        config.morphoMarketAdapterFactoryAddress = vm.envAddress("MORPHO_MARKET_V1_ADAPTER_V2_FACTORY");
        // First market configuration (optional)
        config.marketId = vm.envOr("MARKET_ID", bytes32(0));
        config.collateralTokenCap = uint128(vm.envOr("COLLATERAL_TOKEN_CAP", uint256(0)));
        config.marketCap = uint128(vm.envOr("MARKET_CAP", uint256(0)));
        // Timelock configuration (MORPHO LISTING REQUIREMENT: minimum 3 days = 259200 seconds)
        config.vaultTimelockDuration = vm.envOr("VAULT_TIMELOCK_DURATION", uint256(0));
        config.adapterTimelockDuration = vm.envOr("ADAPTER_TIMELOCK_DURATION", uint256(0));
    }

    /**
     * @notice Main deployment logic with comprehensive vault setup
     * @param config Deployment configuration
     * @return deployedVaultV2Address Address of the deployed VaultV2
     */
    function deployVaultV2WithConfig(DeploymentConfig memory config) internal returns (address) {
        address transactionOriginator = tx.origin;

        vm.startBroadcast();

        // Phase 1: Deploy VaultV2 instance
        VaultV2 deployedVaultV2 =
            _deployVaultV2Instance(config.vaultV2FactoryAddress, transactionOriginator, config.asset);

        // Phase 2: Configure temporary permissions
        _configureTemporaryPermissions(deployedVaultV2, transactionOriginator);

        // Phase 3: Deploy and configure MorphoMarketV1AdapterV2
        address morphoMarketAdapterAddress =
            _deployAndConfigureMorphoMarketAdapter(config.morphoMarketAdapterFactoryAddress, address(deployedVaultV2));

        // Phase 4: Submit timelocked configuration changes
        _submitTimelockedConfigurationChanges(
            deployedVaultV2,
            transactionOriginator,
            config.vaultAllocator,
            config.adapterRegistry,
            morphoMarketAdapterAddress
        );

        // Phase 5: Execute immediate configuration changes (includes critical gates abdication)
        _executeImmediateConfigurationChanges(
            deployedVaultV2,
            transactionOriginator,
            config.vaultAllocator,
            config.adapterRegistry,
            morphoMarketAdapterAddress
        );

        // Phase 6: Set final role assignments
        _setFinalRoleAssignments(deployedVaultV2, config.vaultOwner, config.vaultCurator, config.vaultSentinel);

        // ============================================================================
        // Phase 7: Configure market and liquidity adapter if specified
        // ============================================================================
        // MORPHO LISTING REQUIREMENT: No Idle Liquidity
        // ============================================================================
        // The listing requirement states: "Vault asset balance must be zero"
        //
        // This means ALL deposited funds must be allocated to markets, not sitting
        // idle in the vault contract. The liquidityAdapter automatically allocates
        // incoming deposits to the configured market.
        //
        // WITHOUT a market configured (MARKET_ID = 0):
        //   - liquidityAdapter is NOT set
        //   - Deposits stay idle in the vault
        //   - This violates the "No Idle Liquidity" listing requirement
        //   - The vault will NOT be eligible for Morpho app listing
        //
        // WITH a market configured:
        //   - liquidityAdapter is set with encoded MarketParams
        //   - Deposits automatically allocate to the market
        //   - Vault satisfies the "No Idle Liquidity" requirement
        // ============================================================================
        //
        // IMPORTANT: This must happen BEFORE the dead deposit because:
        // - MorphoMarketV1AdapterV2 requires encoded MarketParams in liquidityData
        // - If liquidityAdapter is set with empty data, allocate() will revert on abi.decode
        // - Without a market, we leave liquidityAdapter unset so deposits stay idle in vault
        if (config.marketId != bytes32(0)) {
            _configureMarketAndLiquidityAdapter(
                deployedVaultV2, IMorphoMarketV1AdapterV2(morphoMarketAdapterAddress), config
            );
        } else {
            console.log("Phase 7: Skipped - no MARKET_ID provided");
            console.log("  liquidityAdapter NOT set - deposits will stay idle in vault");
            console.log("  WARNING: Vault will NOT meet 'No Idle Liquidity' listing requirement");
            console.log("  Configure a market before accepting external deposits");
        }

        // Phase 8: Execute vault dead deposit (always required for inflation attack protection)
        // Now works correctly because liquidityAdapter is either:
        // - Set with encoded MarketParams (allocates to market)
        // - Not set (deposits stays idle in vault)
        _executeVaultDeadDeposit(deployedVaultV2, config.asset);

        // ============================================================================
        // Phase 9: Configure vault timelocks (BEFORE transferring ownership)
        // ============================================================================
        // MORPHO LISTING REQUIREMENT: Timelocks must be configured
        // - 7 days minimum: increaseTimelock, removeAdapter, abdicate
        // - 3 days minimum: addAdapter, increaseRelativeCap, setForceDeallocatePenalty, increaseAbsoluteCap
        //
        // NOTE: We configure all functions with the same duration for simplicity.
        // The minimum required is 3 days (259200 seconds) for listing eligibility.
        // ============================================================================
        if (config.vaultTimelockDuration > 0) {
            _configureVaultTimelocks(deployedVaultV2, config.vaultTimelockDuration);
        } else {
            console.log("Phase 9: Skipped - VAULT_TIMELOCK_DURATION is 0");
            console.log("  WARNING: Vault will NOT meet Morpho listing requirements without timelocks");
        }

        // ============================================================================
        // Phase 10: Configure adapter timelocks
        // ============================================================================
        // MORPHO LISTING REQUIREMENT: burnShares timelock must be >= 3 days
        //
        // The adapter has its own independent timelock system separate from the vault.
        // Key functions that need timelocks:
        // - burnShares: Prevents immediate share burning (protects against manipulation)
        // - setSkimRecipient: Controls who receives skimmed tokens
        // - abdicate: Permanently disables functions
        // ============================================================================
        if (config.adapterTimelockDuration > 0) {
            _configureAdapterTimelocks(
                IMorphoMarketV1AdapterV2(morphoMarketAdapterAddress), config.adapterTimelockDuration
            );
        } else {
            console.log("Phase 10: Skipped - ADAPTER_TIMELOCK_DURATION is 0");
            console.log("  WARNING: Adapter will NOT meet Morpho listing requirements without timelocks");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("VaultV2:", address(deployedVaultV2));
        console.log("MorphoMarketV1AdapterV2:", morphoMarketAdapterAddress);
        console.log("");
        if (config.marketId == bytes32(0)) {
            console.log("NEXT STEPS:");
            console.log("1. Ensure target markets have dead deposits (1e9 shares to 0xdead)");
            console.log("2. Configure collateral token caps for each collateral you want to use");
            console.log("3. Configure market caps for each market you want to allocate to");
            console.log("See docs/build_own_script.md for detailed instructions.");
        } else {
            console.log("First market configured. To add more markets:");
            console.log("1. Ensure target markets have dead deposits (1e9 shares to 0xdead)");
            console.log("2. Configure collateral token caps and market caps via vault functions");
        }
        console.log("===========================");

        return address(deployedVaultV2);
    }

    /**
     * @notice Deploy the VaultV2 instance using the factory
     */
    function _deployVaultV2Instance(address factoryAddress, address temporaryOwner, address underlyingAsset)
        internal
        returns (VaultV2 deployedVault)
    {
        bytes32 uniqueSalt = keccak256(abi.encodePacked(block.timestamp + gasleft()));

        deployedVault =
            VaultV2(VaultV2Factory(factoryAddress).createVaultV2(temporaryOwner, underlyingAsset, uniqueSalt));

        console.log("Phase 1: VaultV2 deployed at:", address(deployedVault));
    }

    /**
     * @notice Configure temporary permissions for deployment process
     */
    function _configureTemporaryPermissions(VaultV2 vault, address temporaryCurator) internal {
        vault.setCurator(temporaryCurator);
        console.log("Phase 2: Temporary curator assigned:", temporaryCurator);
    }

    /**
     * @notice Deploy and verify the MorphoMarketV1AdapterV2
     */
    function _deployAndConfigureMorphoMarketAdapter(address factoryAddress, address vaultV2Address)
        internal
        returns (address adapterAddress)
    {
        IMorphoMarketV1AdapterV2Factory factory = IMorphoMarketV1AdapterV2Factory(factoryAddress);

        adapterAddress = factory.createMorphoMarketV1AdapterV2(vaultV2Address);

        // Verify factory registration
        require(factory.isMorphoMarketV1AdapterV2(adapterAddress), "Adapter not registered in factory");

        // Verify adapter configuration
        IMorphoMarketV1AdapterV2 adapter = IMorphoMarketV1AdapterV2(adapterAddress);
        require(adapter.parentVault() == vaultV2Address, "Parent vault mismatch");

        console.log("Phase 3: MorphoMarketV1AdapterV2 deployed at:", adapterAddress);
        console.log("  Morpho:", adapter.morpho());
        console.log("  Adaptive Curve IRM:", adapter.adaptiveCurveIrm());
    }

    /**
     * @notice Submit timelocked configuration changes (includes critical gates abdication)
     */
    function _submitTimelockedConfigurationChanges(
        VaultV2 vault,
        address temporaryAllocator,
        address finalAllocator,
        address registry,
        address adapter
    ) internal {
        // Submit allocator role changes
        vault.submit(abi.encodeCall(vault.setIsAllocator, (temporaryAllocator, true)));
        if (temporaryAllocator != finalAllocator) {
            vault.submit(abi.encodeCall(vault.setIsAllocator, (temporaryAllocator, false)));
            vault.submit(abi.encodeCall(vault.setIsAllocator, (finalAllocator, true)));
        }

        // Submit adapter registry configuration
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (registry)));

        // NOTE: liquidityAdapterAndData is NOT set here - it requires encoded MarketParams
        // It will be set in _configureMarketAndLiquidityAdapter when a market is specified

        // Submit adapter and cap configurations
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));

        // Submit abdication for setAdapterRegistry
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));

        // Verify gates are set to address(0) before submitting abdication
        require(vault.receiveSharesGate() == address(0), "receiveSharesGate must be address(0) before abdication");
        require(vault.sendSharesGate() == address(0), "sendSharesGate must be address(0) before abdication");
        require(vault.receiveAssetsGate() == address(0), "receiveAssetsGate must be address(0) before abdication");

        // Submit abdication for critical gates (preserves non-custodial properties)
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        console.log("Phase 4: Timelocked configuration changes submitted");
        console.log("  Includes critical gates abdication requests");
    }

    /**
     * @notice Execute immediate configuration changes (includes critical gates abdication)
     * @dev Executes all configuration and abdications while timelock is still 0
     */
    function _executeImmediateConfigurationChanges(
        VaultV2 vault,
        address temporaryAllocator,
        address finalAllocator,
        address registry,
        address adapter
    ) internal {
        // Execute adapter registry configuration
        vault.setAdapterRegistry(registry);

        // Execute allocator role configuration
        vault.setIsAllocator(temporaryAllocator, true);

        // Execute adapter configuration
        vault.addAdapter(adapter);

        // NOTE: liquidityAdapterAndData is NOT set here - it requires encoded MarketParams
        // It will be set in _configureMarketAndLiquidityAdapter when a market is specified

        // Execute adapter-level cap configurations
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);

        // Finalize allocator role changes
        if (temporaryAllocator != finalAllocator) {
            vault.setIsAllocator(temporaryAllocator, false);
            vault.setIsAllocator(finalAllocator, true);
        }

        // Execute abdication for setAdapterRegistry
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);

        // Execute abdication for critical gates (preserves non-custodial properties)
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // Verify all abdications were successful
        require(vault.abdicated(IVaultV2.setAdapterRegistry.selector), "setAdapterRegistry abdication failed");
        require(vault.abdicated(IVaultV2.setReceiveSharesGate.selector), "setReceiveSharesGate abdication failed");
        require(vault.abdicated(IVaultV2.setSendSharesGate.selector), "setSendSharesGate abdication failed");
        require(vault.abdicated(IVaultV2.setReceiveAssetsGate.selector), "setReceiveAssetsGate abdication failed");

        console.log("Phase 5: Immediate configuration changes executed");
        console.log("  Adapter registry set and abdicated");
        console.log("  Adapter-level caps configured (unlimited)");
        console.log("  Critical gates abdicated (non-custodial properties preserved)");
    }

    /**
     * @notice Set final role assignments for the vault
     */
    function _setFinalRoleAssignments(VaultV2 vault, address vaultOwner, address vaultCurator, address vaultSentinel)
        internal
    {
        vault.setCurator(vaultCurator);

        if (vaultSentinel != address(0)) {
            vault.setIsSentinel(vaultSentinel, true);
        }

        vault.setOwner(vaultOwner);

        console.log("Phase 6: Final role assignments completed");
        console.log("  Owner:", vaultOwner);
        console.log("  Curator:", vaultCurator);
        if (vaultSentinel != address(0)) {
            console.log("  Sentinel:", vaultSentinel);
        }
    }

    /**
     * @notice Get the required dead deposit amount based on asset decimals
     * @dev Returns 1e9 for assets with >= 10 decimals, 1e12 for assets with <= 9 decimals
     *      This ensures sufficient protection against inflation attacks regardless of token decimals
     */
    function _getDeadDepositAmount(address asset) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(asset).decimals();
        return decimals >= DECIMALS_THRESHOLD ? DEAD_DEPOSIT_HIGH_DECIMALS : DEAD_DEPOSIT_LOW_DECIMALS;
    }

    /**
     * @notice Execute dead deposit to seed the vault with initial liquidity
     * @dev Always required for inflation attack protection. Amount is determined by asset decimals.
     *      In simulation mode (without --broadcast), the deployer may not have tokens,
     *      so we use a try/catch to handle this gracefully.
     */
    function _executeVaultDeadDeposit(VaultV2 vault, address asset) internal {
        uint256 depositAmount = _getDeadDepositAmount(asset);
        address depositor = tx.origin;

        // Check deployer's balance
        uint256 balance = IERC20(asset).balanceOf(depositor);
        if (balance < depositAmount) {
            console.log("Phase 8: SKIPPED - Insufficient token balance for dead deposit");
            console.log("  Required:", depositAmount);
            console.log("  Available:", balance);
            console.log("  NOTE: In production, ensure deployer has sufficient tokens");
            console.log("  The dead deposit is REQUIRED before the vault can accept external deposits");
            return;
        }

        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, address(0xdead));
        console.log("Phase 8: Vault dead deposit executed:", depositAmount, "wei to 0xdead");
    }

    /**
     * @notice Configure the first market with liquidity adapter setup and cap configuration
     * @dev This function:
     *      1. Looks up MarketParams from Morpho using idToMarketParams
     *      2. Validates market params (loanToken matches asset, irm matches adaptiveCurveIrm)
     *      3. Sets liquidityAdapterAndData with encoded MarketParams (required for allocate)
     *      4. Checks if market has dead deposit (>= required shares at 0xdead)
     *      5. If not, supplies to create dead deposit
     *      6. Configures collateral token cap
     *      7. Configures market cap
     *
     *      IMPORTANT: liquidityAdapterAndData must be set with encoded MarketParams because
     *      MorphoMarketV1AdapterV2.allocate() does: `abi.decode(data, (MarketParams))`
     *      Setting it with empty data causes allocate to revert.
     */
    function _configureMarketAndLiquidityAdapter(
        VaultV2 vault,
        IMorphoMarketV1AdapterV2 adapter,
        DeploymentConfig memory config
    ) internal {
        address morpho = adapter.morpho();

        // Look up MarketParams from Morpho
        MarketParams memory marketParams = IMorpho(morpho).idToMarketParams(Id.wrap(config.marketId));

        // Validate market params
        _validateMarketParams(marketParams, config.asset, adapter.adaptiveCurveIrm());

        console.log("Phase 7: Configuring market and liquidity adapter");
        console.log("  Market ID:", vm.toString(config.marketId));
        console.log("  Collateral Token:", marketParams.collateralToken);
        console.log("  Oracle:", marketParams.oracle);
        console.log("  LLTV:", marketParams.lltv);

        // KEY FIX: Set liquidityAdapterAndData with encoded MarketParams
        // This is required because MorphoMarketV1AdapterV2.allocate() decodes the data as MarketParams
        bytes memory liquidityData = abi.encode(marketParams);
        vault.submit(abi.encodeCall(vault.setLiquidityAdapterAndData, (address(adapter), liquidityData)));
        vault.setLiquidityAdapterAndData(address(adapter), liquidityData);

        console.log("  Liquidity adapter set with encoded MarketParams");

        // Determine required dead deposit amount based on asset decimals
        uint256 requiredDeadDeposit = _getDeadDepositAmount(config.asset);

        // Check if market has sufficient dead deposit
        Position memory deadPosition = IMorpho(morpho).position(Id.wrap(config.marketId), address(0xdead));
        uint256 deadSupplyShares = deadPosition.supplyShares;

        if (deadSupplyShares < requiredDeadDeposit) {
            console.log("  Market needs dead deposit, current shares:", deadSupplyShares);
            console.log("  Required shares:", requiredDeadDeposit);

            // Check deployer's balance for market dead deposit
            uint256 balance = IERC20(config.asset).balanceOf(tx.origin);
            if (balance < requiredDeadDeposit) {
                console.log("  SKIPPED - Insufficient token balance for market dead deposit");
                console.log("  Required:", requiredDeadDeposit);
                console.log("  Available:", balance);
                console.log("  NOTE: In production, ensure market has dead deposit before use");
            } else {
                // Approve and supply to create dead deposit
                IERC20(config.asset).approve(morpho, requiredDeadDeposit);
                IMorpho(morpho).supply(marketParams, requiredDeadDeposit, 0, address(0xdead), hex"");
                console.log("  Market dead deposit created:", requiredDeadDeposit, "assets to 0xdead");
            }
        } else {
            console.log("  Market already has sufficient dead deposit:", deadSupplyShares, "shares");
        }

        // Configure collateral token caps (absolute + 100% relative)
        bytes memory collateralTokenIdData = abi.encode("collateralToken", marketParams.collateralToken);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (collateralTokenIdData, config.collateralTokenCap)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (collateralTokenIdData, 1e18)));
        vault.increaseAbsoluteCap(collateralTokenIdData, config.collateralTokenCap);
        vault.increaseRelativeCap(collateralTokenIdData, 1e18);

        console.log("  Collateral token cap set:", config.collateralTokenCap, "(absolute), 100% (relative)");

        // Configure market caps (absolute + 100% relative)
        bytes memory marketIdData = abi.encode("this/marketParams", address(adapter), marketParams);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (marketIdData, config.marketCap)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (marketIdData, 1e18)));
        vault.increaseAbsoluteCap(marketIdData, config.marketCap);
        vault.increaseRelativeCap(marketIdData, 1e18);

        console.log("  Market cap set:", config.marketCap, "(absolute), 100% (relative)");
    }

    /**
     * @notice Validate that MarketParams match expected values
     * @param marketParams The market parameters to validate
     * @param expectedAsset The expected loan token address (vault's underlying asset)
     * @param expectedIrm The expected IRM address (adapter's adaptiveCurveIrm)
     */
    function _validateMarketParams(MarketParams memory marketParams, address expectedAsset, address expectedIrm)
        internal
        pure
    {
        require(marketParams.loanToken == expectedAsset, "Market loanToken does not match vault asset");
        require(marketParams.irm == expectedIrm, "Market IRM does not match adaptiveCurveIrm");
        require(marketParams.collateralToken != address(0), "Market not found (collateralToken is zero)");
    }

    /**
     * @notice Configure timelocks for VaultV2 functions
     * @param vault The VaultV2 instance to configure
     * @param timelockDuration The timelock duration in seconds
     * @dev MORPHO LISTING REQUIREMENT: Timelocks must be 3-7 days depending on function
     *      - 7 days minimum: increaseTimelock, removeAdapter, abdicate
     *      - 3 days minimum: addAdapter, increaseRelativeCap, setForceDeallocatePenalty, increaseAbsoluteCap
     *
     *      IMPORTANT: increaseTimelock.selector must be configured LAST because once timelocked,
     *      subsequent calls require waiting for the timelock to expire.
     *
     *      This function configures all timelocked functions with the same duration for simplicity.
     *      For production deployments, you may want to configure different durations per function.
     */
    function _configureVaultTimelocks(VaultV2 vault, uint256 timelockDuration) internal {
        // Configure timelocks for key vault functions
        // Order matters: increaseTimelock.selector MUST be last!
        bytes4[] memory selectors = new bytes4[](7);
        // 3-day minimum functions
        selectors[0] = IVaultV2.addAdapter.selector;
        selectors[1] = IVaultV2.increaseAbsoluteCap.selector;
        selectors[2] = IVaultV2.increaseRelativeCap.selector;
        selectors[3] = IVaultV2.setForceDeallocatePenalty.selector;
        // 7-day minimum functions
        selectors[4] = IVaultV2.abdicate.selector;
        selectors[5] = IVaultV2.removeAdapter.selector;
        selectors[6] = IVaultV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < selectors.length; i++) {
            vault.submit(abi.encodeCall(vault.increaseTimelock, (selectors[i], timelockDuration)));
            vault.increaseTimelock(selectors[i], timelockDuration);
        }

        console.log("Phase 9: Vault timelocks configured:", timelockDuration, "seconds");
    }

    /**
     * @notice Configure timelocks for MorphoMarketV1AdapterV2 functions
     * @param adapter The adapter instance to configure
     * @param timelockDuration The timelock duration in seconds
     * @dev MORPHO LISTING REQUIREMENT: burnShares timelock must be >= 3 days
     *
     *      The adapter has its own independent timelock system separate from the vault.
     *      Key functions that need timelocks:
     *      - burnShares: Prevents immediate share burning (protects against manipulation)
     *      - setSkimRecipient: Controls who receives skimmed tokens
     *      - abdicate: Permanently disables functions
     *
     *      IMPORTANT: increaseTimelock.selector must be configured LAST because once timelocked,
     *      subsequent calls require waiting for the timelock to expire.
     */
    function _configureAdapterTimelocks(IMorphoMarketV1AdapterV2 adapter, uint256 timelockDuration) internal {
        // Configure timelocks for key adapter functions
        // Order matters: increaseTimelock.selector MUST be last!
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IMorphoMarketV1AdapterV2.abdicate.selector;
        selectors[1] = IMorphoMarketV1AdapterV2.setSkimRecipient.selector;
        selectors[2] = IMorphoMarketV1AdapterV2.burnShares.selector;
        selectors[3] = IMorphoMarketV1AdapterV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < selectors.length; i++) {
            adapter.submit(abi.encodeCall(adapter.increaseTimelock, (selectors[i], timelockDuration)));
            adapter.increaseTimelock(selectors[i], timelockDuration);
        }

        console.log("Phase 10: Adapter timelocks configured:", timelockDuration, "seconds");
    }
}
