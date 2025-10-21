// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";

/**
 * @title SetRegistryToZero
 * @notice Submit and execute setAdapterRegistry to zero address
 */
contract SetRegistryToZero is Script {
    address public constant VAULT = 0x8A7a3Cb46bca02491711275f5C837E23220539b0;
    address public constant ZERO_ADDRESS = address(0);

    function run() external {
        console.log("Setting adapter registry to zero address...");
        console.log("Vault:", VAULT);
        console.log("");

        vm.startBroadcast();

        IVaultV2 vault = IVaultV2(VAULT);

        // Step 1: Submit
        bytes memory setRegistryData = abi.encodeCall(IVaultV2.setAdapterRegistry, (ZERO_ADDRESS));
        vault.submit(setRegistryData);
        console.log("[1] Submitted setAdapterRegistry(address(0))");

        // Step 2: Execute
        vault.setAdapterRegistry(ZERO_ADDRESS);
        console.log("[2] Executed setAdapterRegistry(address(0))");

        vm.stopBroadcast();

        console.log("");
        console.log("Registry set to:", vault.adapterRegistry());
        console.log("Done!");
    }
}
