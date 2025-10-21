// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";

/**
 * @title AddAllocator
 * @notice Add a new allocator to the vault using timelock process
 * @dev Requires curator to call submit() then setIsAllocator()
 *
 * USAGE:
 * forge script script/AddAllocator.s.sol:AddAllocator --sig "run()" \
 *   --rpc-url https://base-mainnet.g.alchemy.com/v2/YOUR_KEY \
 *   --broadcast \
 *   --private-key CURATOR_PRIVATE_KEY \
 *   -vvv
 *
 * ENVIRONMENT VARIABLES:
 * - VAULT_ADDRESS: The vault contract address
 * - NEW_ALLOCATOR: The address to add as allocator
 */
contract AddAllocator is Script {
    // ============================================
    // CONFIGURATION
    // ============================================

    address public vault;
    address public newAllocator;

    // ============================================
    // MAIN FUNCTION
    // ============================================

    /**
     * @notice Add a new allocator to the vault
     * @dev Process: submit() -> wait for timelock (0 in this case) -> setIsAllocator()
     */
    function run() external {
        _loadConfig();

        console.log("====================================");
        console.log("  ADD ALLOCATOR - START");
        console.log("====================================");
        console.log("Vault:", vault);
        console.log("New Allocator:", newAllocator);
        console.log("");

        IVaultV2 vaultContract = IVaultV2(vault);

        // Check current status
        bool isCurrentlyAllocator = vaultContract.isAllocator(newAllocator);
        console.log("[STATUS] Is currently allocator:", isCurrentlyAllocator);

        if (isCurrentlyAllocator) {
            console.log("");
            console.log("WARNING: Address is already an allocator!");
            console.log("No action needed.");
            return;
        }

        vm.startBroadcast();

        // Step 1: Submit the setIsAllocator call
        console.log("");
        console.log("[STEP 1] Submitting setIsAllocator to timelock...");

        bytes memory setAllocatorData = abi.encodeCall(IVaultV2.setIsAllocator, (newAllocator, true));

        vaultContract.submit(setAllocatorData);
        console.log("[SUBMITTED] Transaction queued in timelock");
        _logCalldata("submit", setAllocatorData);

        // Get timelock for this function
        bytes4 selector = IVaultV2.setIsAllocator.selector;
        uint256 timelockDuration = vaultContract.timelock(selector);
        console.log("[INFO] Timelock duration:", timelockDuration, "seconds");

        // Step 2: Execute setIsAllocator (works immediately if timelock = 0)
        console.log("");
        console.log("[STEP 2] Executing setIsAllocator...");

        vaultContract.setIsAllocator(newAllocator, true);
        console.log("[EXECUTED] Allocator added successfully");
        _logCalldata("setIsAllocator", abi.encodeCall(IVaultV2.setIsAllocator, (newAllocator, true)));

        vm.stopBroadcast();

        // Verify
        console.log("");
        console.log("[VERIFICATION] Checking final status...");
        bool isFinallyAllocator = vaultContract.isAllocator(newAllocator);
        console.log("Is allocator:", isFinallyAllocator);

        console.log("");
        console.log("====================================");
        console.log("  ADD ALLOCATOR - COMPLETE");
        console.log("====================================");
        console.log("");
        console.log("Summary:");
        console.log("  Vault:", vault);
        console.log("  New Allocator:", newAllocator);
        console.log("  Status:", isFinallyAllocator ? "ACTIVE" : "FAILED");
        console.log("");
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    /**
     * @notice Load configuration from environment variables
     */
    function _loadConfig() internal {
        vault = vm.envAddress("VAULT_ADDRESS");
        newAllocator = vm.envAddress("NEW_ALLOCATOR");

        require(vault != address(0), "VAULT_ADDRESS not set");
        require(newAllocator != address(0), "NEW_ALLOCATOR not set");
    }

    /**
     * @notice Log calldata for Etherscan reproduction
     */
    function _logCalldata(string memory functionName, bytes memory data) internal view {
        console.log("  Calldata for", functionName, ":");
        console.logBytes(data);
    }
}
