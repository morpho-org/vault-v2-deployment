// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";

/**
 * @title SetCaps
 * @notice Set caps for an adapter (VaultV1 or ERC4626 style)
 * @dev For VaultV1/ERC4626 adapters, only adapter-level caps are needed
 *
 * USAGE:
 * export VAULT_ADDRESS=0x8A7a3Cb46bca02491711275f5C837E23220539b0
 * export ADAPTER=0x98Cb0aB186F459E65936DB0C0E457F0D7d349c65
 * export ABSOLUTE_CAP=340282366920938463463374607431768211455  # max uint128
 * export RELATIVE_CAP=1000000000000000000  # 1e18 = 100%
 *
 * forge script script/SetCaps.s.sol:SetCaps --sig "run()" \
 *   --rpc-url https://base-mainnet.g.alchemy.com/v2/YOUR_KEY \
 *   --broadcast \
 *   --private-key CURATOR_PRIVATE_KEY \
 *   -vvv
 */
contract SetCaps is Script {
    address public vault;
    address public adapter;
    uint256 public absoluteCap;
    uint256 public relativeCap;

    function run() external {
        _loadConfig();

        console.log("====================================");
        console.log("  SET CAPS - START");
        console.log("====================================");
        console.log("Vault:", vault);
        console.log("Adapter:", adapter);
        console.log("Absolute Cap:", absoluteCap);
        console.log("Relative Cap:", relativeCap);
        console.log("");

        IVaultV2 vaultContract = IVaultV2(vault);

        // Calculate adapter ID
        bytes memory adapterIdData = abi.encode("this", adapter);
        bytes32 adapterId = keccak256(adapterIdData);

        // Check current caps
        uint256 currentAbsoluteCap = vaultContract.absoluteCap(adapterId);
        uint256 currentRelativeCap = vaultContract.relativeCap(adapterId);

        console.log("[STATUS] Current caps:");
        console.log("  Absolute:", currentAbsoluteCap);
        console.log("  Relative:", currentRelativeCap);
        console.log("");

        vm.startBroadcast();

        // Step 1: Submit + Execute Absolute Cap
        if (absoluteCap > currentAbsoluteCap) {
            console.log("[STEP 1] Setting absolute cap...");

            bytes memory increaseAbsoluteData =
                abi.encodeCall(IVaultV2.increaseAbsoluteCap, (adapterIdData, absoluteCap));

            vaultContract.submit(increaseAbsoluteData);
            console.log("[SUBMITTED] Absolute cap");

            vaultContract.increaseAbsoluteCap(adapterIdData, absoluteCap);
            console.log("[EXECUTED] Absolute cap set to:", absoluteCap);
            _logCalldata("increaseAbsoluteCap", increaseAbsoluteData);
        } else {
            console.log("[SKIP] Absolute cap already >=", absoluteCap);
        }

        console.log("");

        // Step 2: Submit + Execute Relative Cap
        if (relativeCap > currentRelativeCap) {
            console.log("[STEP 2] Setting relative cap...");

            bytes memory increaseRelativeData =
                abi.encodeCall(IVaultV2.increaseRelativeCap, (adapterIdData, relativeCap));

            vaultContract.submit(increaseRelativeData);
            console.log("[SUBMITTED] Relative cap");

            vaultContract.increaseRelativeCap(adapterIdData, relativeCap);
            console.log("[EXECUTED] Relative cap set to:", relativeCap);
            _logCalldata("increaseRelativeCap", increaseRelativeData);
        } else {
            console.log("[SKIP] Relative cap already >=", relativeCap);
        }

        vm.stopBroadcast();

        // Verify
        console.log("");
        console.log("[VERIFICATION] Final caps:");
        uint256 finalAbsoluteCap = vaultContract.absoluteCap(adapterId);
        uint256 finalRelativeCap = vaultContract.relativeCap(adapterId);
        console.log("  Absolute:", finalAbsoluteCap);
        console.log("  Relative:", finalRelativeCap);

        console.log("");
        console.log("====================================");
        console.log("  SET CAPS - COMPLETE");
        console.log("====================================");
    }

    function _loadConfig() internal {
        vault = vm.envAddress("VAULT_ADDRESS");
        adapter = vm.envAddress("ADAPTER");

        // Default to max if not specified
        try vm.envUint("ABSOLUTE_CAP") returns (uint256 cap) {
            absoluteCap = cap;
        } catch {
            absoluteCap = type(uint128).max;
        }

        try vm.envUint("RELATIVE_CAP") returns (uint256 cap) {
            relativeCap = cap;
        } catch {
            relativeCap = 1e18;
        }
    }

    function _logCalldata(string memory functionName, bytes memory data) internal view {
        console.log("  Calldata:");
        console.logBytes(data);
    }
}
