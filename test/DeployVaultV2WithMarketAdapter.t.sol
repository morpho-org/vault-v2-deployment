// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IMorphoMarketV1AdapterV2} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2.sol";
import {IMorphoMarketV1AdapterV2Factory} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2Factory.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Id, Position} from "morpho-blue/src/interfaces/IMorpho.sol";
import {DeployVaultV2WithMarketAdapter} from "../script/DeployVaultV2WithMarketAdapter.s.sol";

/**
 * @title DeployVaultV2WithMarketAdapterTest
 * @notice Tests deployment logic for VaultV2 with MorphoMarketV1AdapterV2 on Base mainnet fork
 */
contract DeployVaultV2WithMarketAdapterTest is Test {
    // Base mainnet addresses
    address constant VAULT_V2_FACTORY = 0x4501125508079A99ebBebCE205DeC9593C2b5857;
    address constant MORPHO_MARKET_V1_ADAPTER_V2_FACTORY = 0x9a1B378C43BA535cDB89934230F0D3890c51C0EB;
    address constant ADAPTER_REGISTRY = 0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Test market: USDC/cbBTC with Adaptive Curve IRM
    bytes32 constant MARKET_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    uint256 constant DEAD_DEPOSIT_AMOUNT = 1e12; // For 6 decimal asset
    uint128 constant COLLATERAL_TOKEN_CAP = type(uint128).max; // Unlimited for testing
    uint128 constant MARKET_CAP = type(uint128).max; // Unlimited for testing

    address deployer = makeAddr("deployer");

    // Deployed contracts - set by _deploy()
    VaultV2 vault;
    address adapter;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");
        deal(USDC, deployer, 100_000_000e6);
    }

    /**
     * @notice Deploy without a market (liquidityAdapter not set)
     * @dev Dead deposit stays idle in vault
     */
    function _deployWithoutMarket() internal {
        vm.startPrank(deployer);

        // Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));

        // Set temporary curator
        vault.setCurator(deployer);

        // Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        // Submit all timelocked changes (NO liquidityAdapterAndData - requires market params)
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        // Execute all changes (NO liquidityAdapterAndData)
        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // Dead deposit (stays idle in vault since no liquidityAdapter)
        IERC20(USDC).approve(address(vault), DEAD_DEPOSIT_AMOUNT);
        vault.deposit(DEAD_DEPOSIT_AMOUNT, address(0xdead));

        vm.stopPrank();
    }

    /**
     * @notice Deploy with a market (liquidityAdapter set with encoded MarketParams)
     * @dev Dead deposit allocates to the configured market
     */
    function _deployWithMarket() internal {
        vm.startPrank(deployer);

        // Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));

        // Set temporary curator
        vault.setCurator(deployer);

        // Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        // Submit all timelocked changes (NO liquidityAdapterAndData yet)
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        // Execute all changes (NO liquidityAdapterAndData yet)
        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // Configure market and liquidity adapter BEFORE dead deposit
        _configureMarketAndLiquidityAdapter();

        // Dead deposit (allocates to market via liquidityAdapter)
        IERC20(USDC).approve(address(vault), DEAD_DEPOSIT_AMOUNT);
        vault.deposit(DEAD_DEPOSIT_AMOUNT, address(0xdead));

        vm.stopPrank();
    }

    /**
     * @notice Configure market with encoded MarketParams for liquidityAdapterAndData
     */
    function _configureMarketAndLiquidityAdapter() internal {
        // Look up MarketParams from Morpho
        MarketParams memory marketParams = IMorpho(MORPHO).idToMarketParams(Id.wrap(MARKET_ID));

        // Validate market params
        require(marketParams.loanToken == USDC, "Market loanToken mismatch");
        require(marketParams.irm == ADAPTIVE_CURVE_IRM, "Market IRM mismatch");
        require(marketParams.collateralToken == CBBTC, "Market collateralToken mismatch");

        // KEY FIX: Set liquidityAdapterAndData with encoded MarketParams
        bytes memory liquidityData = abi.encode(marketParams);
        vault.submit(abi.encodeCall(vault.setLiquidityAdapterAndData, (adapter, liquidityData)));
        vault.setLiquidityAdapterAndData(adapter, liquidityData);

        // Check if market has sufficient dead deposit, if not create one
        uint256 requiredDeadDeposit = DEAD_DEPOSIT_AMOUNT;
        Position memory deadPosition = IMorpho(MORPHO).position(Id.wrap(MARKET_ID), address(0xdead));
        if (deadPosition.supplyShares < requiredDeadDeposit) {
            IERC20(USDC).approve(MORPHO, requiredDeadDeposit);
            IMorpho(MORPHO).supply(marketParams, requiredDeadDeposit, 0, address(0xdead), hex"");
        }

        // Configure collateral token caps
        bytes memory collateralTokenIdData = abi.encode("collateralToken", marketParams.collateralToken);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (collateralTokenIdData, COLLATERAL_TOKEN_CAP)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (collateralTokenIdData, 1e18)));
        vault.increaseAbsoluteCap(collateralTokenIdData, COLLATERAL_TOKEN_CAP);
        vault.increaseRelativeCap(collateralTokenIdData, 1e18);

        // Configure market caps
        bytes memory marketIdData = abi.encode("this/marketParams", adapter, marketParams);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (marketIdData, MARKET_CAP)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (marketIdData, 1e18)));
        vault.increaseAbsoluteCap(marketIdData, MARKET_CAP);
        vault.increaseRelativeCap(marketIdData, 1e18);
    }

    function test_DeployWithoutMarket() public {
        _deployWithoutMarket();

        assertEq(vault.asset(), USDC, "Asset should be USDC");
        assertEq(vault.owner(), deployer, "Owner should be deployer");
        assertEq(vault.curator(), deployer, "Curator should be deployer");

        assertEq(vault.adaptersLength(), 1, "Should have 1 adapter");
        assertEq(vault.adapters(0), adapter, "Adapter should match");

        IMorphoMarketV1AdapterV2 adapterContract = IMorphoMarketV1AdapterV2(adapter);
        assertEq(adapterContract.morpho(), MORPHO, "Should point to Morpho");
        assertEq(adapterContract.adaptiveCurveIrm(), ADAPTIVE_CURVE_IRM, "Should use correct IRM");
        assertEq(adapterContract.parentVault(), address(vault), "Parent vault should match");

        // Without market, liquidityAdapter should NOT be set
        assertEq(vault.liquidityAdapter(), address(0), "Liquidity adapter should NOT be set");

        assertTrue(vault.abdicated(IVaultV2.setAdapterRegistry.selector), "setAdapterRegistry abdicated");
        assertTrue(vault.abdicated(IVaultV2.setReceiveSharesGate.selector), "setReceiveSharesGate abdicated");
        assertTrue(vault.abdicated(IVaultV2.setSendSharesGate.selector), "setSendSharesGate abdicated");
        assertTrue(vault.abdicated(IVaultV2.setReceiveAssetsGate.selector), "setReceiveAssetsGate abdicated");

        assertGt(vault.balanceOf(address(0xdead)), 0, "Dead deposit made");

        // Verify funds stayed in vault (idle) since no liquidityAdapter
        assertGe(IERC20(USDC).balanceOf(address(vault)), DEAD_DEPOSIT_AMOUNT, "Funds should stay idle in vault");

        console.log("=== DEPLOYMENT WITHOUT MARKET VERIFIED ===");
        console.log("VaultV2:", address(vault));
        console.log("Adapter:", adapter);
        console.log("liquidityAdapter: NOT SET (deposits stay idle)");
    }

    function test_DeployWithMarket() public {
        _deployWithMarket();

        assertEq(vault.asset(), USDC, "Asset should be USDC");
        assertEq(vault.owner(), deployer, "Owner should be deployer");

        assertEq(vault.adaptersLength(), 1, "Should have 1 adapter");
        assertEq(vault.adapters(0), adapter, "Adapter should match");

        // With market, liquidityAdapter SHOULD be set
        assertEq(vault.liquidityAdapter(), adapter, "Liquidity adapter should be set");

        // Verify liquidityData contains encoded MarketParams
        bytes memory liquidityData = vault.liquidityData();
        assertGt(liquidityData.length, 0, "liquidityData should not be empty");

        // Decode and verify MarketParams
        MarketParams memory decodedParams = abi.decode(liquidityData, (MarketParams));
        assertEq(decodedParams.loanToken, USDC, "Decoded loanToken should be USDC");
        assertEq(decodedParams.collateralToken, CBBTC, "Decoded collateralToken should be cbBTC");
        assertEq(decodedParams.irm, ADAPTIVE_CURVE_IRM, "Decoded IRM should match");

        assertTrue(vault.abdicated(IVaultV2.setAdapterRegistry.selector), "setAdapterRegistry abdicated");

        assertGt(vault.balanceOf(address(0xdead)), 0, "Dead deposit made");

        // Verify funds were allocated to market (not idle in vault)
        assertLt(IERC20(USDC).balanceOf(address(vault)), DEAD_DEPOSIT_AMOUNT, "Funds should be allocated to market");

        console.log("=== DEPLOYMENT WITH MARKET VERIFIED ===");
        console.log("VaultV2:", address(vault));
        console.log("Adapter:", adapter);
        console.log("liquidityAdapter: SET with encoded MarketParams");
    }

    function test_AdapterRegistryAbdicated() public {
        _deployWithoutMarket();

        assertEq(vault.adapterRegistry(), ADAPTER_REGISTRY, "Registry should be set");

        vm.prank(deployer);
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (address(0x123))));

        vm.expectRevert();
        vm.prank(deployer);
        vault.setAdapterRegistry(address(0x123));
    }

    function test_GatesAbdicated() public {
        _deployWithoutMarket();

        assertEq(vault.receiveSharesGate(), address(0), "receiveSharesGate should be zero");
        assertEq(vault.sendSharesGate(), address(0), "sendSharesGate should be zero");
        assertEq(vault.receiveAssetsGate(), address(0), "receiveAssetsGate should be zero");

        vm.startPrank(deployer);

        vault.submit(abi.encodeCall(vault.setReceiveSharesGate, (address(0x1))));
        vm.expectRevert();
        vault.setReceiveSharesGate(address(0x1));

        vm.stopPrank();
    }

    function test_DepositWithdrawWithoutMarket() public {
        _deployWithoutMarket();

        address user = makeAddr("user");
        uint256 depositAmount = 1000e6;
        deal(USDC, user, depositAmount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive shares");

        // Funds stay idle in vault
        assertGe(IERC20(USDC).balanceOf(address(vault)), depositAmount, "Funds should stay in vault");

        vm.startPrank(user);
        uint256 withdrawn = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertApproxEqAbs(withdrawn, depositAmount, 1, "Should withdraw same amount");

        console.log("Deposited:", depositAmount);
        console.log("Withdrawn:", withdrawn);
    }

    function test_DepositWithdrawWithMarket() public {
        _deployWithMarket();

        address user = makeAddr("user");
        uint256 depositAmount = 1000e6;
        deal(USDC, user, depositAmount);

        vm.startPrank(user);
        IERC20(USDC).approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive shares");

        // Funds allocated to market (minimal in vault)
        assertLt(IERC20(USDC).balanceOf(address(vault)), depositAmount, "Funds should be allocated to market");

        vm.startPrank(user);
        uint256 withdrawn = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertApproxEqAbs(withdrawn, depositAmount, 1, "Should withdraw same amount");

        console.log("Deposited:", depositAmount);
        console.log("Withdrawn:", withdrawn);
    }

    function test_AdapterCaps() public {
        _deployWithoutMarket();

        bytes32 adapterId = keccak256(abi.encode("this", adapter));

        assertEq(vault.absoluteCap(adapterId), type(uint128).max, "Absolute cap should be max");
        assertEq(vault.relativeCap(adapterId), 1e18, "Relative cap should be 100%");
    }

    function test_MarketCapsWithMarket() public {
        _deployWithMarket();

        // Check collateral token cap
        bytes32 collateralTokenId = keccak256(abi.encode("collateralToken", CBBTC));
        assertEq(vault.absoluteCap(collateralTokenId), COLLATERAL_TOKEN_CAP, "Collateral token cap should be set");
        assertEq(vault.relativeCap(collateralTokenId), 1e18, "Collateral token relative cap should be 100%");

        // Check market cap
        MarketParams memory marketParams = IMorpho(MORPHO).idToMarketParams(Id.wrap(MARKET_ID));
        bytes32 marketParamsId = keccak256(abi.encode("this/marketParams", adapter, marketParams));
        assertEq(vault.absoluteCap(marketParamsId), MARKET_CAP, "Market cap should be set");
        assertEq(vault.relativeCap(marketParamsId), 1e18, "Market relative cap should be 100%");
    }

    /**
     * @notice Test that setting liquidityAdapter with empty data causes allocate to fail
     * @dev This demonstrates the bug we fixed
     */
    function test_EmptyLiquidityDataCausesRevert() public {
        vm.startPrank(deployer);

        // Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));
        vault.setCurator(deployer);

        // Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        // Setup minimal config
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        // BUG: Setting liquidityAdapterAndData with empty bytes
        vault.submit(abi.encodeCall(vault.setLiquidityAdapterAndData, (adapter, bytes(""))));

        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        // BUG: Setting liquidityAdapterAndData with empty bytes
        vault.setLiquidityAdapterAndData(adapter, bytes(""));

        // Try to deposit - should revert because allocate tries to decode empty bytes as MarketParams
        IERC20(USDC).approve(address(vault), DEAD_DEPOSIT_AMOUNT);
        vm.expectRevert(); // abi.decode of empty bytes will fail
        vault.deposit(DEAD_DEPOSIT_AMOUNT, address(0xdead));

        vm.stopPrank();

        console.log("=== CONFIRMED: Empty liquidityData causes revert on deposit ===");
    }

    /**
     * @notice Test deployment with vault timelocks configured
     * @dev Verifies that vault timelocks are properly set for listing requirements
     */
    function test_DeployWithVaultTimelocks() public {
        uint256 timelockDuration = 3 days; // 259200 seconds - minimum for listing

        vm.startPrank(deployer);

        // Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));
        vault.setCurator(deployer);

        // Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        // Setup minimal config
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));

        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);

        // Configure vault timelocks (order matters: increaseTimelock.selector MUST be last!)
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = IVaultV2.addAdapter.selector;
        selectors[1] = IVaultV2.increaseAbsoluteCap.selector;
        selectors[2] = IVaultV2.increaseRelativeCap.selector;
        selectors[3] = IVaultV2.setForceDeallocatePenalty.selector;
        selectors[4] = IVaultV2.abdicate.selector;
        selectors[5] = IVaultV2.removeAdapter.selector;
        selectors[6] = IVaultV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < selectors.length; i++) {
            vault.submit(abi.encodeCall(vault.increaseTimelock, (selectors[i], timelockDuration)));
            vault.increaseTimelock(selectors[i], timelockDuration);
        }

        vm.stopPrank();

        // Verify all vault timelocks are set
        assertEq(vault.timelock(IVaultV2.addAdapter.selector), timelockDuration, "addAdapter timelock");
        assertEq(
            vault.timelock(IVaultV2.increaseAbsoluteCap.selector), timelockDuration, "increaseAbsoluteCap timelock"
        );
        assertEq(
            vault.timelock(IVaultV2.increaseRelativeCap.selector), timelockDuration, "increaseRelativeCap timelock"
        );
        assertEq(
            vault.timelock(IVaultV2.setForceDeallocatePenalty.selector),
            timelockDuration,
            "setForceDeallocatePenalty timelock"
        );
        assertEq(vault.timelock(IVaultV2.abdicate.selector), timelockDuration, "abdicate timelock");
        assertEq(vault.timelock(IVaultV2.removeAdapter.selector), timelockDuration, "removeAdapter timelock");
        assertEq(vault.timelock(IVaultV2.increaseTimelock.selector), timelockDuration, "increaseTimelock timelock");

        console.log("=== VAULT TIMELOCKS CONFIGURED ===");
        console.log("Timelock duration:", timelockDuration, "seconds");
    }

    /**
     * @notice Test deployment with adapter timelocks configured
     * @dev Verifies that adapter timelocks are properly set for listing requirements
     */
    function test_DeployWithAdapterTimelocks() public {
        uint256 timelockDuration = 3 days; // 259200 seconds - minimum for listing

        vm.startPrank(deployer);

        // Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));
        vault.setCurator(deployer);

        // Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        IMorphoMarketV1AdapterV2 adapterContract = IMorphoMarketV1AdapterV2(adapter);

        // Configure adapter timelocks (order matters: increaseTimelock.selector MUST be last!)
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IMorphoMarketV1AdapterV2.abdicate.selector;
        selectors[1] = IMorphoMarketV1AdapterV2.setSkimRecipient.selector;
        selectors[2] = IMorphoMarketV1AdapterV2.burnShares.selector;
        selectors[3] = IMorphoMarketV1AdapterV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < selectors.length; i++) {
            adapterContract.submit(abi.encodeCall(adapterContract.increaseTimelock, (selectors[i], timelockDuration)));
            adapterContract.increaseTimelock(selectors[i], timelockDuration);
        }

        vm.stopPrank();

        // Verify all adapter timelocks are set
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.abdicate.selector), timelockDuration, "abdicate timelock"
        );
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.setSkimRecipient.selector),
            timelockDuration,
            "setSkimRecipient timelock"
        );
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.burnShares.selector),
            timelockDuration,
            "burnShares timelock"
        );
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.increaseTimelock.selector),
            timelockDuration,
            "increaseTimelock timelock"
        );

        console.log("=== ADAPTER TIMELOCKS CONFIGURED ===");
        console.log("Timelock duration:", timelockDuration, "seconds");
    }

    /**
     * @notice Test full deployment with timelocks (manual recreation of script logic)
     * @dev Manually recreates the deployment flow since vm.startBroadcast is incompatible with vm.prank
     */
    function test_FullDeploymentWithTimelocks() public {
        uint256 timelockDuration = 3 days; // 259200 seconds

        vm.startPrank(deployer);

        // Phase 1: Deploy VaultV2
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));

        // Phase 2: Set temporary curator
        vault.setCurator(deployer);

        // Phase 3: Deploy adapter
        adapter = IMorphoMarketV1AdapterV2Factory(MORPHO_MARKET_V1_ADAPTER_V2_FACTORY)
            .createMorphoMarketV1AdapterV2(address(vault));

        // Phase 4 & 5: Configure vault
        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // Phase 8: Dead deposit (no market so deposits stay idle)
        IERC20(USDC).approve(address(vault), DEAD_DEPOSIT_AMOUNT);
        vault.deposit(DEAD_DEPOSIT_AMOUNT, address(0xdead));

        // Phase 9: Configure vault timelocks
        bytes4[] memory vaultSelectors = new bytes4[](7);
        vaultSelectors[0] = IVaultV2.addAdapter.selector;
        vaultSelectors[1] = IVaultV2.increaseAbsoluteCap.selector;
        vaultSelectors[2] = IVaultV2.increaseRelativeCap.selector;
        vaultSelectors[3] = IVaultV2.setForceDeallocatePenalty.selector;
        vaultSelectors[4] = IVaultV2.abdicate.selector;
        vaultSelectors[5] = IVaultV2.removeAdapter.selector;
        vaultSelectors[6] = IVaultV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < vaultSelectors.length; i++) {
            vault.submit(abi.encodeCall(vault.increaseTimelock, (vaultSelectors[i], timelockDuration)));
            vault.increaseTimelock(vaultSelectors[i], timelockDuration);
        }

        // Phase 10: Configure adapter timelocks
        IMorphoMarketV1AdapterV2 adapterContract = IMorphoMarketV1AdapterV2(adapter);
        bytes4[] memory adapterSelectors = new bytes4[](4);
        adapterSelectors[0] = IMorphoMarketV1AdapterV2.abdicate.selector;
        adapterSelectors[1] = IMorphoMarketV1AdapterV2.setSkimRecipient.selector;
        adapterSelectors[2] = IMorphoMarketV1AdapterV2.burnShares.selector;
        adapterSelectors[3] = IMorphoMarketV1AdapterV2.increaseTimelock.selector; // MUST BE LAST!

        for (uint256 i = 0; i < adapterSelectors.length; i++) {
            adapterContract.submit(
                abi.encodeCall(adapterContract.increaseTimelock, (adapterSelectors[i], timelockDuration))
            );
            adapterContract.increaseTimelock(adapterSelectors[i], timelockDuration);
        }

        vm.stopPrank();

        // Verify vault timelocks are set
        assertEq(vault.timelock(IVaultV2.addAdapter.selector), timelockDuration, "addAdapter timelock");
        assertEq(vault.timelock(IVaultV2.abdicate.selector), timelockDuration, "abdicate timelock");
        assertEq(vault.timelock(IVaultV2.increaseTimelock.selector), timelockDuration, "increaseTimelock timelock");

        // Verify adapter timelocks are set
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.burnShares.selector),
            timelockDuration,
            "burnShares timelock"
        );
        assertEq(
            adapterContract.timelock(IMorphoMarketV1AdapterV2.abdicate.selector), timelockDuration, "abdicate timelock"
        );

        console.log("=== FULL DEPLOYMENT WITH TIMELOCKS VERIFIED ===");
        console.log("VaultV2:", address(vault));
        console.log("Adapter:", adapter);
        console.log("Timelock duration:", timelockDuration, "seconds");
    }
}
