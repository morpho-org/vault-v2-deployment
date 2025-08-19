// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {MorphoVaultV1Adapter} from "vault-v2/adapters/MorphoVaultV1Adapter.sol";

import {IERC4626 as IVaultV1} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

contract DeployVaultV2 is Script {
    function run() external returns (address) {
        // --- Wallet addresses  ---
        address owner = vm.envAddress("OWNER");
        address curator = vm.envAddress("CURATOR");
        address allocator = vm.envAddress("ALLOCATOR");
        address sentinel = vm.envExists("SENTINEL") ? vm.envAddress("SENTINEL") : address(0);

        // --- TimelockDuration  ---
        uint256 timelockDuration = vm.envExists("TIMELOCK_DURATION") ? vm.envUint("TIMELOCK_DURATION") : 0;

        // --- Vault V1 address  ---
        IVaultV1 vaultV1 = IVaultV1(vm.envAddress("VAULT_V1"));

        return runWithArguments(owner, curator, allocator, sentinel, timelockDuration, vaultV1);
    }

    function runWithArguments(
        address owner,
        address curator,
        address allocator,
        address sentinel,
        uint256 timelockDuration,
        IVaultV1 vaultV1
    ) public returns (address) {
        address broadcaster = tx.origin;

        vm.startBroadcast();

        // --- Step 1: Deploy the VaultV2 Instance, with the broadcaster as temporary owner ---
        VaultV2 vaultV2 = new VaultV2(broadcaster, vaultV1.asset());
        console.log("VaultV2 deployed at:", address(vaultV2));

        // --- Step 2: Temporary grant Curator role to the broadcaster ---
        vaultV2.setCurator(broadcaster);
        console.log("Broadcaster set as Curator");

        // --- Step 3: Deploy the MorphoVaultV1 Adapter ---
        address morphoVaultV1Adapter = address(new MorphoVaultV1Adapter(address(vaultV2), address(vaultV1)));
        console.log("MorphoVaultV1Adapter deployed at:", morphoVaultV1Adapter);

        // --- Step 4: Submit All Timelocked Actions (+ Allocator Role) ---
        bytes memory idData = abi.encode("this", morphoVaultV1Adapter);
        vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, true)));
        if (broadcaster != allocator) {
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, false)));
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (allocator, true)));
        }
        vaultV2.submit(abi.encodeCall(vaultV2.setIsAdapter, (morphoVaultV1Adapter, true)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseRelativeCap, (idData, 1e18)));
        console.log("All timelocked actions submitted");

        // Functions have timelock[selector] = 0 by default, so should be executable immediately after submit

        // --- Step 5: Execute the actions ---
        vaultV2.setIsAllocator(broadcaster, true);
        if (broadcaster != allocator) {
            vaultV2.setIsAllocator(allocator, true);
        }
        vaultV2.setIsAdapter(morphoVaultV1Adapter, true);
        vaultV2.increaseAbsoluteCap(idData, type(uint128).max);
        vaultV2.increaseRelativeCap(idData, 1e18);
        console.log("All timelocked actions executed");

        // --- Step 6: Set the Liquidity Market ---
        vaultV2.setLiquidityAdapterAndData(morphoVaultV1Adapter, bytes(""));
        console.log("Allocator set the liquidity market");

        // -- Step 7: remove allocator role before setting TL ---
        if (broadcaster != allocator) {
            vaultV2.setIsAllocator(broadcaster, false);
        }

        // -- Step 8: set the timelocks
        if (timelockDuration > 0) {
            vaultV2.increaseTimelock(IVaultV2.setIsAllocator.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setSharesGate.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setReceiveAssetsGate.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setSendAssetsGate.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setIsAdapter.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.abdicateSubmit.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setPerformanceFee.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setManagementFee.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setPerformanceFeeRecipient.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setManagementFeeRecipient.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.increaseAbsoluteCap.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.increaseRelativeCap.selector, timelockDuration);
            vaultV2.increaseTimelock(IVaultV2.setForceDeallocatePenalty.selector, timelockDuration);
            console.log("Allocator timelocks increased");
        }

        // --- Step 9: Set the Roles ---
        vaultV2.setCurator(curator);
        if (sentinel != address(0)) {
            vaultV2.setIsSentinel(sentinel, true);
        }
        vaultV2.setOwner(owner);
        console.log("All roles set");

        vm.stopBroadcast();
        return address(vaultV2);
    }
}
