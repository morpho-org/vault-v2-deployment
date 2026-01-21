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
 */
contract DeployVaultV2WithMarketAdapter is Script {
    uint256 constant DEAD_DEPOSIT_HIGH_DECIMALS = 1e9; // For assets with >= 10 decimals
    uint256 constant DEAD_DEPOSIT_LOW_DECIMALS = 1e12; // For assets with <= 9 decimals
    uint8 constant DECIMALS_THRESHOLD = 10;

    /**
     * @notice Configuration struct for deployment parameters
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
        uint128 marketCap
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
            marketCap: marketCap
        });

        return deployVaultV2WithConfig(config);
    }

    /**
     * @notice Read configuration from environment variables
     * @return config Deployment configuration struct
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

        // Phase 7: Execute vault dead deposit (always required for inflation attack protection)
        _executeVaultDeadDeposit(deployedVaultV2, config.asset);

        // Phase 8: Configure first market if specified
        if (config.marketId != bytes32(0)) {
            _configureFirstMarket(deployedVaultV2, IMorphoMarketV1AdapterV2(morphoMarketAdapterAddress), config);
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

        // Submit liquidity adapter configuration
        vault.submit(abi.encodeCall(vault.setLiquidityAdapterAndData, (adapter, bytes(""))));

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
        vault.setLiquidityAdapterAndData(adapter, bytes(""));

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
     */
    function _executeVaultDeadDeposit(VaultV2 vault, address asset) internal {
        uint256 depositAmount = _getDeadDepositAmount(asset);
        IERC20(asset).approve(address(vault), depositAmount);
        vault.deposit(depositAmount, address(0xdead));
        console.log("Phase 7: Vault dead deposit executed:", depositAmount, "wei to 0xdead");
    }

    /**
     * @notice Configure the first market with dead deposit check and cap setup
     * @dev This function:
     *      1. Looks up MarketParams from Morpho using idToMarketParams
     *      2. Validates market params (loanToken matches asset, irm matches adaptiveCurveIrm)
     *      3. Checks if market has dead deposit (>= required shares at 0xdead)
     *      4. If not, supplies to create dead deposit
     *      5. Configures collateral token cap
     *      6. Configures market cap
     */
    function _configureFirstMarket(VaultV2 vault, IMorphoMarketV1AdapterV2 adapter, DeploymentConfig memory config)
        internal
    {
        address morpho = adapter.morpho();

        // Look up MarketParams from Morpho
        MarketParams memory marketParams = IMorpho(morpho).idToMarketParams(Id.wrap(config.marketId));

        // Validate market params
        require(marketParams.loanToken == config.asset, "Market loanToken does not match vault asset");
        require(marketParams.irm == adapter.adaptiveCurveIrm(), "Market IRM does not match adaptiveCurveIrm");
        require(marketParams.collateralToken != address(0), "Market not found (collateralToken is zero)");

        console.log("Phase 8: Configuring first market");
        console.log("  Market ID:", vm.toString(config.marketId));
        console.log("  Collateral Token:", marketParams.collateralToken);
        console.log("  Oracle:", marketParams.oracle);
        console.log("  LLTV:", marketParams.lltv);

        // Determine required dead deposit amount based on asset decimals
        uint256 requiredDeadDeposit = _getDeadDepositAmount(config.asset);

        // Check if market has sufficient dead deposit
        Position memory deadPosition = IMorpho(morpho).position(Id.wrap(config.marketId), address(0xdead));
        uint256 deadSupplyShares = deadPosition.supplyShares;

        if (deadSupplyShares < requiredDeadDeposit) {
            console.log("  Market needs dead deposit, current shares:", deadSupplyShares);
            console.log("  Required shares:", requiredDeadDeposit);

            // Approve and supply to create dead deposit
            IERC20(config.asset).approve(morpho, requiredDeadDeposit);
            IMorpho(morpho).supply(marketParams, requiredDeadDeposit, 0, address(0xdead), hex"");

            console.log("  Market dead deposit created:", requiredDeadDeposit, "assets to 0xdead");
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
}
