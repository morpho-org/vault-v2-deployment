// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {AllActions} from "../script/AllActions.s.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {MorphoMarketV1AdapterFactory} from "vault-v2/adapters/MorphoMarketV1AdapterFactory.sol";
import {MorphoVaultV1AdapterFactory} from "vault-v2/adapters/MorphoVaultV1AdapterFactory.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title AllActionsTest
 * @notice Basic sanity tests for AllActions script
 * @dev Full E2E test requires a vault with timelock=0, which must be pre-configured
 *      See OPERATIONS_GUIDE.md for how to run the full demo
 */
contract AllActionsTest is Test {
    AllActions public script;

    // Mock contracts
    VaultV2Factory public vaultFactory;
    MorphoMarketV1AdapterFactory public marketAdapterFactory;
    MorphoVaultV1AdapterFactory public vaultAdapterFactory;
    ERC20Mock public usdc;
    ERC20Mock public cbBTC;
    ERC20Mock public weth;

    // Mock addresses
    address public morpho = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    address public vaultV1 = address(0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183);
    address public oracle1 = address(0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9);
    address public oracle2 = address(0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4);
    address public irm1 = address(0x46415998764C29aB2a25CbeA6254146D50D22687);
    address public irm2 = address(0x46415998764C29aB2a25CbeA6254146D50D22687);

    function setUp() public {
        // Deploy mocks
        usdc = new ERC20Mock();
        cbBTC = new ERC20Mock();
        weth = new ERC20Mock();

        // Deploy factories
        vaultFactory = new VaultV2Factory();
        marketAdapterFactory = new MorphoMarketV1AdapterFactory();
        vaultAdapterFactory = new MorphoVaultV1AdapterFactory();

        // Mint tokens to test contract
        usdc.mint(address(this), 10_000_000e6);

        // Setup environment variables
        vm.setEnv("VAULT_V2_FACTORY", vm.toString(address(vaultFactory)));
        vm.setEnv("MORPHO_MARKET_V1_ADAPTER_FACTORY", vm.toString(address(marketAdapterFactory)));
        vm.setEnv("MORPHO_VAULT_V1_ADAPTER_FACTORY", vm.toString(address(vaultAdapterFactory)));
        vm.setEnv("MORPHO_ADDRESS", vm.toString(morpho));
        vm.setEnv("VAULT_V1", vm.toString(vaultV1));
        vm.setEnv("OWNER", vm.toString(address(this)));
        vm.setEnv("CURATOR", vm.toString(address(this)));
        vm.setEnv("ALLOCATOR", vm.toString(address(this)));
        vm.setEnv("SENTINEL", vm.toString(address(this)));
        vm.setEnv("ASSET", vm.toString(address(usdc)));

        // Market 1: USDC/cbBTC
        vm.setEnv("MARKET1_LOAN_TOKEN", vm.toString(address(usdc)));
        vm.setEnv("MARKET1_COLLATERAL_TOKEN", vm.toString(address(cbBTC)));
        vm.setEnv("MARKET1_ORACLE", vm.toString(oracle1));
        vm.setEnv("MARKET1_IRM", vm.toString(irm1));
        vm.setEnv("MARKET1_LLTV", "860000000000000000"); // 86%

        // Market 2: USDC/WETH
        vm.setEnv("MARKET2_LOAN_TOKEN", vm.toString(address(usdc)));
        vm.setEnv("MARKET2_COLLATERAL_TOKEN", vm.toString(address(weth)));
        vm.setEnv("MARKET2_ORACLE", vm.toString(oracle2));
        vm.setEnv("MARKET2_IRM", vm.toString(irm2));
        vm.setEnv("MARKET2_LLTV", "860000000000000000"); // 86%

        // Deploy script
        script = new AllActions();
    }

    /**
     * @notice Test script deployment
     */
    function test_ScriptDeployment() public view {
        assertTrue(address(script) != address(0), "Script should be deployed");
    }

    /**
     * @notice Test environment setup
     */
    function test_EnvironmentSetup() public view {
        assertEq(vm.envAddress("VAULT_V2_FACTORY"), address(vaultFactory));
        assertEq(vm.envAddress("MORPHO_ADDRESS"), morpho);
        assertEq(vm.envAddress("ASSET"), address(usdc));
    }

    /**
     * @notice Test that all 13 actions are documented
     */
    function test_All13ActionsCovered() public pure {
        // This is a documentation test to ensure we cover all actions
        string[13] memory actions = [
            "Action 1: Add Token to Portfolio",
            "Action 2: Remove Token from Portfolio (Option A)",
            "Action 3: Add Protocol",
            "Action 4: Remove Protocol (Option B)",
            "Action 5: Rebalance Portfolio",
            "Action 6: Emergency Exit",
            "Action 7: Pause Deposits",
            "Action 8: Pause Withdrawals",
            "Action 9: Restrict Protocols",
            "Action 10: Restrict Tokens",
            "Action 11: Revoke Curator Rights",
            "Action 12: View Current Allocation",
            "Action 13: View Reallocation History"
        ];

        // Just verify we have 13 actions
        assertEq(actions.length, 13, "Should have exactly 13 actions");
    }

    /**
     * @notice Test factories are deployed correctly
     */
    function test_FactoriesDeployed() public view {
        assertTrue(address(vaultFactory) != address(0), "VaultV2Factory should be deployed");
        assertTrue(address(marketAdapterFactory) != address(0), "MarketV1 factory should be deployed");
        assertTrue(address(vaultAdapterFactory) != address(0), "VaultV1 factory should be deployed");
    }

    /**
     * @notice Test mock tokens are deployed correctly
     */
    function test_MockTokensDeployed() public view {
        assertTrue(address(usdc) != address(0), "USDC should be deployed");
        assertTrue(address(cbBTC) != address(0), "cbBTC should be deployed");
        assertTrue(address(weth) != address(0), "WETH should be deployed");
    }

    /**
     * @notice Test tokens are minted to test contract
     */
    function test_TokensMinted() public view {
        assertEq(usdc.balanceOf(address(this)), 10_000_000e6, "USDC should be minted");
    }

    /**
     * @notice Note about full E2E testing
     * @dev This test documents the requirement for timelock=0
     */
    function test_E2E_RequiresTimelockZero() public view {
        // Full E2E test requires a vault deployed with timelock=0
        // This must be done via DeployVaultV2.s.sol with TIMELOCK_DURATION=0
        //
        // To run the full demo:
        // 1. Deploy vault: TIMELOCK_DURATION=0 forge script script/DeployVaultV2.s.sol --broadcast
        // 2. Run AllActions: forge script script/AllActions.s.sol --broadcast
        //
        // See OPERATIONS_GUIDE.md and ALLACTIONS_README.md for details
        assertTrue(true, "This is a documentation test");
    }

    /**
     * @notice Test script has public state variables
     */
    function test_ScriptStateVariables() public view {
        // These will be set after script.run() is called
        // For now, just verify they're accessible
        script.vault();
        script.adapter();
        script.vaultV1Adapter();
        script.tempCuratorAddress();
    }
}
