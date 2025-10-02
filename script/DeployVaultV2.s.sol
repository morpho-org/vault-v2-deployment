// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {MorphoVaultV1AdapterFactory} from "vault-v2/adapters/MorphoVaultV1AdapterFactory.sol";

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
        address registry = vm.envAddress("ADAPTER_REGISTRY");
        address vaultV2Factory = vm.envAddress("VAULT_V2_FACTORY");
        address morphoVaultV1AdapterFactory = vm.envAddress("MORPHO_VAULT_V1_ADAPTER_FACTORY");

        return runWithArguments(
            owner,
            curator,
            allocator,
            sentinel,
            timelockDuration,
            vaultV1,
            registry,
            vaultV2Factory,
            morphoVaultV1AdapterFactory
        );
    }

    function runWithArguments(
        address owner,
        address curator,
        address allocator,
        address sentinel,
        uint256 timelockDuration,
        IVaultV1 vaultV1,
        address registry,
        address vaultV2Factory,
        address morphoVaultV1AdapterFactory
    ) public returns (address) {
        return runWithArguments(
            owner,
            curator,
            allocator,
            sentinel,
            timelockDuration,
            vaultV1,
            registry,
            vaultV2Factory,
            morphoVaultV1AdapterFactory,
            keccak256(abi.encodePacked(block.timestamp + gasleft())) // unique salt
        );
    }

    function runWithArguments(
        address owner,
        address curator,
        address allocator,
        address sentinel,
        uint256 timelockDuration,
        IVaultV1 vaultV1,
        address registry,
        address vaultV2Factory,
        address morphoVaultV1AdapterFactory,
        bytes32 salt
    ) public returns (address) {
        address broadcaster = tx.origin;

        vm.startBroadcast();

        // --- Step 1: Deploy the VaultV2 Instance, with the broadcaster as temporary owner ---
        VaultV2 vaultV2 = VaultV2(VaultV2Factory(vaultV2Factory).createVaultV2(broadcaster, vaultV1.asset(), salt));
        console.log("VaultV2 deployed at:", address(vaultV2));

        // --- Step 2: Temporary grant Curator role to the broadcaster ---
        vaultV2.setCurator(broadcaster);
        console.log("Broadcaster set as Curator");

        // --- Step 4: Deploy the MorphoVaultV1 Adapter ---
        address morphoVaultV1Adapter = MorphoVaultV1AdapterFactory(morphoVaultV1AdapterFactory)
            .createMorphoVaultV1Adapter(address(vaultV2), address(vaultV1));
        console.log("MorphoVaultV1Adapter deployed at:", morphoVaultV1Adapter);

        // --- Step 5: Submit All Timelocked Actions ---

        // 5.1 Allocators role
        vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, true)));
        if (broadcaster != allocator) {
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, false)));
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (allocator, true)));
        }

        // 5.2 Registry
        vaultV2.submit(abi.encodeCall(vaultV2.setAdapterRegistry, (registry)));

        // 5.3 Adapter
        vaultV2.submit(abi.encodeCall(vaultV2.setLiquidityAdapterAndData, (morphoVaultV1Adapter, bytes(""))));

        // 5.4 Caps
        bytes memory idData = abi.encode("this", morphoVaultV1Adapter);
        vaultV2.submit(abi.encodeCall(vaultV2.addAdapter, (morphoVaultV1Adapter)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseRelativeCap, (idData, 1e18)));

        console.log("All timelocked actions submitted");

        // --- Step 6: Execute the submitted actions ---

        // 6.1 Registry
        vaultV2.setAdapterRegistry(registry);

        // 6.2 Allocators role
        vaultV2.setIsAllocator(broadcaster, true);

        // 6.3 Adapter
        vaultV2.addAdapter(morphoVaultV1Adapter);
        vaultV2.setLiquidityAdapterAndData(morphoVaultV1Adapter, bytes(""));

        // 6.4 Caps
        vaultV2.increaseAbsoluteCap(idData, type(uint128).max);
        vaultV2.increaseRelativeCap(idData, 1e18);

        // 6.5 Allocators role
        if (broadcaster != allocator) {
            vaultV2.setIsAllocator(broadcaster, false);
            vaultV2.setIsAllocator(allocator, true);
        }

        vaultV2.submit(abi.encodeCall(vaultV2.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vaultV2.abdicate(IVaultV2.setAdapterRegistry.selector);

        // -- Step 9: set the timelocks
        if (timelockDuration > 0) {
            // List of function selectors to set timelock for
            bytes4[] memory selectors = new bytes4[](10);
            selectors[0] = IVaultV2.setReceiveSharesGate.selector;
            selectors[1] = IVaultV2.setSendSharesGate.selector;
            selectors[2] = IVaultV2.setReceiveAssetsGate.selector;
            selectors[3] = IVaultV2.addAdapter.selector;
            selectors[4] = IVaultV2.increaseAbsoluteCap.selector;
            selectors[5] = IVaultV2.increaseRelativeCap.selector;
            selectors[6] = IVaultV2.setForceDeallocatePenalty.selector;
            selectors[7] = IVaultV2.abdicate.selector;
            selectors[8] = IVaultV2.removeAdapter.selector;
            selectors[9] = IVaultV2.increaseTimelock.selector;

            // Submit timelock increases for all selectors
            for (uint256 i = 0; i < selectors.length; i++) {
                vaultV2.submit(abi.encodeCall(vaultV2.increaseTimelock, (selectors[i], timelockDuration)));
            }
            console.log("All timelock increases submitted");

            // Execute the timelock increases for all selectors
            for (uint256 i = 0; i < selectors.length; i++) {
                vaultV2.increaseTimelock(selectors[i], timelockDuration);
            }
            console.log("All timelock increases executed");
        }

        // --- Step 10: Set the Roles ---
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
