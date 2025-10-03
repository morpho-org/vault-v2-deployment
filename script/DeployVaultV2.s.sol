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
        // Input validation
        require(owner != address(0), "Owner cannot be zero address");
        require(curator != address(0), "Curator cannot be zero address");
        require(allocator != address(0), "Allocator cannot be zero address");
        require(address(vaultV1) != address(0), "VaultV1 cannot be zero address");
        require(registry != address(0), "Registry cannot be zero address");
        require(vaultV2Factory != address(0), "VaultV2Factory cannot be zero address");
        require(morphoVaultV1AdapterFactory != address(0), "MorphoVaultV1AdapterFactory cannot be zero address");

        // Validate that addresses are contracts (except sentinel which can be zero)
        require(address(vaultV1).code.length > 0, "VaultV1 must be a contract");
        require(registry.code.length > 0, "Registry must be a contract");
        require(vaultV2Factory.code.length > 0, "VaultV2Factory must be a contract");
        require(morphoVaultV1AdapterFactory.code.length > 0, "MorphoVaultV1AdapterFactory must be a contract");

        // Validate VaultV1 has the expected interface
        try vaultV1.asset() returns (address) {
            // VaultV1 has asset() function, which is good
        } catch {
            revert("VaultV1 must implement IERC4626 interface");
        }

        address broadcaster = tx.origin;

        vm.startBroadcast();

        // --- Step 1: Deploy the VaultV2 Instance, with the broadcaster as temporary owner ---
        VaultV2 vaultV2 = VaultV2(VaultV2Factory(vaultV2Factory).createVaultV2(broadcaster, vaultV1.asset(), salt));
        console.log("VaultV2 deployed at:", address(vaultV2));

        // --- Step 2: Temporary grant Curator role to the broadcaster ---
        vaultV2.setCurator(broadcaster);
        console.log("Broadcaster set as Curator");

        // --- Step 3: Deploy the MorphoVaultV1 Adapter ---
        address morphoVaultV1Adapter = MorphoVaultV1AdapterFactory(morphoVaultV1AdapterFactory)
            .createMorphoVaultV1Adapter(address(vaultV2), address(vaultV1));
        console.log("MorphoVaultV1Adapter deployed at:", morphoVaultV1Adapter);

        // --- Step 4: Submit All Timelocked Actions ---

        // 4.1 Allocators role
        vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, true)));
        if (broadcaster != allocator) {
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (broadcaster, false)));
            vaultV2.submit(abi.encodeCall(vaultV2.setIsAllocator, (allocator, true)));
        }

        // 4.2 Registry
        vaultV2.submit(abi.encodeCall(vaultV2.setAdapterRegistry, (registry)));

        // 4.3 Adapter
        vaultV2.submit(abi.encodeCall(vaultV2.setLiquidityAdapterAndData, (morphoVaultV1Adapter, bytes(""))));

        // 4.4 Caps
        bytes memory idData = abi.encode("this", morphoVaultV1Adapter);
        vaultV2.submit(abi.encodeCall(vaultV2.addAdapter, (morphoVaultV1Adapter)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseAbsoluteCap, (idData, type(uint128).max)));
        vaultV2.submit(abi.encodeCall(vaultV2.increaseRelativeCap, (idData, 1e18)));

        console.log("All timelocked actions submitted");

        // --- Step 5: Execute the submitted actions ---

        // 5.1 Registry
        vaultV2.setAdapterRegistry(registry);

        // 5.2 Allocators role
        vaultV2.setIsAllocator(broadcaster, true);

        // 5.3 Adapter
        vaultV2.addAdapter(morphoVaultV1Adapter);
        vaultV2.setLiquidityAdapterAndData(morphoVaultV1Adapter, bytes(""));

        // 5.4 Caps
        vaultV2.increaseAbsoluteCap(idData, type(uint128).max);
        vaultV2.increaseRelativeCap(idData, 1e18);

        // 5.5 Allocators role
        if (broadcaster != allocator) {
            vaultV2.setIsAllocator(broadcaster, false);
            vaultV2.setIsAllocator(allocator, true);
        }

        vaultV2.submit(abi.encodeCall(vaultV2.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vaultV2.abdicate(IVaultV2.setAdapterRegistry.selector);

        // -- Step 6: set the timelocks
        if (timelockDuration > 0) {
            // List of function selectors to set timelock for
            bytes4[] memory selectors = new bytes4[](9);
            selectors[0] = IVaultV2.setReceiveSharesGate.selector;
            selectors[1] = IVaultV2.setSendSharesGate.selector;
            selectors[2] = IVaultV2.setReceiveAssetsGate.selector;
            selectors[3] = IVaultV2.addAdapter.selector;
            selectors[4] = IVaultV2.increaseAbsoluteCap.selector;
            selectors[5] = IVaultV2.increaseRelativeCap.selector;
            selectors[6] = IVaultV2.setForceDeallocatePenalty.selector;
            selectors[7] = IVaultV2.abdicate.selector;
            selectors[8] = IVaultV2.increaseTimelock.selector;

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

        // --- Step 7: Set the Roles ---
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
