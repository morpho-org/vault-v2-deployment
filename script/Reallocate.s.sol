// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IMorphoMarketV1Adapter} from "vault-v2/adapters/interfaces/IMorphoMarketV1Adapter.sol";
import {IMorphoVaultV1Adapter} from "vault-v2/adapters/interfaces/IMorphoVaultV1Adapter.sol";
import {MarketParams} from "../lib/vault-v2/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Reallocate
 * @notice Deallocate from all adapters and optionally reallocate to a target adapter
 * @dev This script helps avoid out-of-gas issues by processing adapters one at a time
 *
 * USAGE:
 * 1. Deallocate from all adapters:
 *    forge script script/Reallocate.s.sol:Reallocate --sig "deallocateAll()" \
 *      --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY -vvv
 *
 * 2. Deallocate and reallocate to VaultV1 adapter:
 *    forge script script/Reallocate.s.sol:Reallocate --sig "reallocateToVaultV1()" \
 *      --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY -vvv
 *
 * 3. Deallocate and reallocate to a Market:
 *    First set TARGET_ADAPTER, MARKET_LOAN_TOKEN, etc. in .env
 *    forge script script/Reallocate.s.sol:Reallocate --sig "reallocateToMarket()" \
 *      --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY -vvv
 */
contract Reallocate is Script {
    // ============================================
    // CONFIGURATION (Set via environment variables)
    // ============================================

    address public vault; // VAULT_ADDRESS in .env
    address public targetAdapter; // TARGET_ADAPTER in .env (optional, for reallocation)

    // For market reallocation (optional)
    MarketParams public targetMarket;

    // ============================================
    // MAIN FUNCTIONS
    // ============================================

    /**
     * @notice Deallocate from ALL adapters and leave funds in vault
     * @dev Useful for emergency exit or preparing for reallocation
     */
    function deallocateAll() external {
        _loadConfig();

        console.log("====================================");
        console.log("  DEALLOCATE ALL - START");
        console.log("====================================");
        console.log("Vault:", vault);
        console.log("");

        vm.startBroadcast();

        IVaultV2 vaultContract = IVaultV2(vault);
        uint256 totalDeallocated = _deallocateFromAllAdapters(vaultContract);

        vm.stopBroadcast();

        console.log("");
        console.log("====================================");
        console.log("  DEALLOCATE ALL - COMPLETE");
        console.log("====================================");
        console.log("Total deallocated:", totalDeallocated);
        console.log("Vault balance:", IERC20(vaultContract.asset()).balanceOf(vault));
        console.log("");
    }

    /**
     * @notice Deallocate from all adapters and reallocate to VaultV1 adapter
     * @dev VaultV1 adapter is typically used for deposit/withdraw liquidity
     */
    function reallocateToVaultV1() external {
        _loadConfig();

        console.log("====================================");
        console.log("  REALLOCATE TO VAULTV1 - START");
        console.log("====================================");
        console.log("Vault:", vault);
        console.log("Target VaultV1 Adapter:", targetAdapter);
        console.log("");

        vm.startBroadcast();

        IVaultV2 vaultContract = IVaultV2(vault);

        // Step 1: Deallocate from all other adapters
        uint256 totalDeallocated = _deallocateFromAllAdapters(vaultContract);
        console.log("");
        console.log("[REALLOCATION] Total funds available:", totalDeallocated);

        // Step 2: Get actual vault balance (may differ due to rounding)
        uint256 availableBalance = IERC20(vaultContract.asset()).balanceOf(vault);
        console.log("[REALLOCATION] Actual vault balance:", availableBalance);

        // Step 3: Allocate to VaultV1 adapter
        if (availableBalance > 0) {
            console.log("");
            console.log("[REALLOCATION] Allocating to VaultV1 adapter...");

            // VaultV1 adapter uses EMPTY bytes for data
            vaultContract.allocate(targetAdapter, hex"", availableBalance);

            console.log("[REALLOCATION] Allocated", availableBalance, "to VaultV1 adapter");
            _logCalldata("allocate", abi.encodeCall(IVaultV2.allocate, (targetAdapter, hex"", availableBalance)));
        } else {
            console.log("[REALLOCATION] No funds to allocate");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("====================================");
        console.log("  REALLOCATE TO VAULTV1 - COMPLETE");
        console.log("====================================");
        _printAllocationStatus(vaultContract);
    }

    /**
     * @notice Deallocate from all adapters and reallocate to a Morpho Market
     * @dev Market parameters must be set via environment variables
     */
    function reallocateToMarket() external {
        _loadConfig();
        _loadMarketConfig();

        console.log("====================================");
        console.log("  REALLOCATE TO MARKET - START");
        console.log("====================================");
        console.log("Vault:", vault);
        console.log("Target Market Adapter:", targetAdapter);
        console.log("Market Loan Token:", targetMarket.loanToken);
        console.log("Market Collateral Token:", targetMarket.collateralToken);
        console.log("");

        vm.startBroadcast();

        IVaultV2 vaultContract = IVaultV2(vault);

        // Step 1: Deallocate from all other adapters
        uint256 totalDeallocated = _deallocateFromAllAdapters(vaultContract);
        console.log("");
        console.log("[REALLOCATION] Total funds available:", totalDeallocated);

        // Step 2: Get actual vault balance (may differ due to rounding)
        uint256 availableBalance = IERC20(vaultContract.asset()).balanceOf(vault);
        console.log("[REALLOCATION] Actual vault balance:", availableBalance);

        // Step 3: Allocate to target market
        if (availableBalance > 0) {
            console.log("");
            console.log("[REALLOCATION] Allocating to market...");

            // MarketV1 adapter requires abi.encode(MarketParams) for data
            bytes memory marketData = abi.encode(targetMarket);
            vaultContract.allocate(targetAdapter, marketData, availableBalance);

            console.log("[REALLOCATION] Allocated", availableBalance, "to market");
            _logCalldata("allocate", abi.encodeCall(IVaultV2.allocate, (targetAdapter, marketData, availableBalance)));
        } else {
            console.log("[REALLOCATION] No funds to allocate");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("====================================");
        console.log("  REALLOCATE TO MARKET - COMPLETE");
        console.log("====================================");
        _printAllocationStatus(vaultContract);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /**
     * @notice Deallocate from all adapters in the vault
     * @param vaultContract The vault to deallocate from
     * @return totalDeallocated Total amount deallocated across all adapters
     *
     * HOW THIS WORKS:
     * 1. Get the count of adapters from vault.adaptersLength()
     * 2. For each adapter:
     *    a. Get the adapter address via vault.adapters(index)
     *    b. Calculate the adapter's ID: keccak256(abi.encode("this", adapterAddress))
     *    c. Get the current allocation via vault.allocation(adapterId)
     *    d. If allocation > 0, deallocate the funds
     * 3. Different adapter types require different data:
     *    - VaultV1 adapter: data = hex"" (empty bytes)
     *    - MarketV1 adapter: data = abi.encode(MarketParams) but we use adapter-level deallocation
     */
    function _deallocateFromAllAdapters(IVaultV2 vaultContract) internal returns (uint256 totalDeallocated) {
        uint256 adaptersCount = vaultContract.adaptersLength();
        console.log("[DEALLOCATION] Total adapters:", adaptersCount);
        console.log("");

        totalDeallocated = 0;

        for (uint256 i = 0; i < adaptersCount; i++) {
            address adapterAddress = vaultContract.adapters(i);

            // Calculate adapter ID: keccak256(abi.encode("this", adapterAddress))
            bytes32 adapterId = keccak256(abi.encode("this", adapterAddress));

            // Get current allocation for this adapter
            uint256 allocation = vaultContract.allocation(adapterId);

            console.log("Adapter", i + 1, ":", adapterAddress);
            console.log("  Allocation:", allocation);

            if (allocation > 0) {
                // Deallocate funds from this adapter
                // We use adapter-level deallocation with empty data
                // This works for both VaultV1 and MarketV1 adapters
                bytes memory deallocateData = abi.encodeCall(IVaultV2.deallocate, (adapterAddress, hex"", allocation));

                vaultContract.deallocate(adapterAddress, hex"", allocation);

                console.log("  [DEALLOCATED]", allocation, "from adapter");
                _logCalldata("deallocate", deallocateData);

                totalDeallocated += allocation;
            } else {
                console.log("  [SKIP] No allocation");
            }

            console.log("");
        }

        console.log("[DEALLOCATION] Total deallocated:", totalDeallocated);

        return totalDeallocated;
    }

    /**
     * @notice Print current allocation status for all adapters
     * @param vaultContract The vault to query
     */
    function _printAllocationStatus(IVaultV2 vaultContract) internal view {
        uint256 adaptersCount = vaultContract.adaptersLength();

        console.log("Final Allocation Status:");
        console.log("");

        for (uint256 i = 0; i < adaptersCount; i++) {
            address adapterAddress = vaultContract.adapters(i);
            bytes32 adapterId = keccak256(abi.encode("this", adapterAddress));
            uint256 allocation = vaultContract.allocation(adapterId);

            console.log("Adapter", i + 1, ":", adapterAddress);
            console.log("  Allocation:", allocation);

            // Try to get real assets if it's a Morpho adapter
            try IMorphoMarketV1Adapter(adapterAddress).realAssets() returns (uint256 realAssets) {
                console.log("  Real Assets:", realAssets);
            } catch {
                // Not a MarketV1 adapter, skip
            }

            console.log("");
        }

        console.log("Vault balance:", IERC20(vaultContract.asset()).balanceOf(vault));
    }

    /**
     * @notice Load configuration from environment variables
     */
    function _loadConfig() internal {
        vault = vm.envAddress("VAULT_ADDRESS");

        // TARGET_ADAPTER is optional
        try vm.envAddress("TARGET_ADAPTER") returns (address target) {
            targetAdapter = target;
        } catch {
            targetAdapter = address(0);
        }
    }

    /**
     * @notice Load market configuration from environment variables
     */
    function _loadMarketConfig() internal {
        require(targetAdapter != address(0), "TARGET_ADAPTER must be set");

        targetMarket = MarketParams({
            loanToken: vm.envAddress("MARKET_LOAN_TOKEN"),
            collateralToken: vm.envAddress("MARKET_COLLATERAL_TOKEN"),
            oracle: vm.envAddress("MARKET_ORACLE"),
            irm: vm.envAddress("MARKET_IRM"),
            lltv: vm.envUint("MARKET_LLTV")
        });
    }

    /**
     * @notice Log calldata for Etherscan reproduction
     */
    function _logCalldata(string memory functionName, bytes memory data) internal view {
        console.log("  Calldata for", functionName, ":");
        console.logBytes(data);
    }
}
