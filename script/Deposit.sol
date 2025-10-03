// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deposit
 * @notice Example script for depositing assets into a VaultV2
 * @dev This script reads the vault address from environment variables for security
 * @dev WARNING: This script approves the exact amount needed, not unlimited approval
 */
contract Deposit is Script {
    function run() external {
        // Read vault address from environment variable
        address vaultV2Address = vm.envAddress("VAULT_V2_ADDRESS");
        require(vaultV2Address != address(0), "VAULT_V2_ADDRESS must be set");
        
        // Read deposit amount from environment variable (default to 100)
        uint256 depositAmount = vm.envOr("DEPOSIT_AMOUNT", uint256(100));
        
        vm.startBroadcast();
        
        IVaultV2 vaultV2 = IVaultV2(vaultV2Address);
        IERC20 asset = IERC20(vaultV2.asset());
        
        console.log("Depositing to VaultV2 at:", vaultV2Address);
        console.log("Asset address:", address(asset));
        console.log("Deposit amount:", depositAmount);
        
        // Approve only the amount needed (not unlimited)
        asset.approve(address(vaultV2), depositAmount);
        vaultV2.deposit(depositAmount, tx.origin);
        
        console.log("Deposit successful");
        
        vm.stopBroadcast();
    }
}
