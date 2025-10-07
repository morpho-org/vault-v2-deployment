// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {MorphoVaultV1AdapterFactory} from "vault-v2/adapters/MorphoVaultV1AdapterFactory.sol";
import {MorphoMarketV1AdapterFactory} from "vault-v2/adapters/MorphoMarketV1AdapterFactory.sol";

contract DeployFactories is Script {
    function run() external returns (address, address, address) {
        vm.startBroadcast();

        address vaultV2Factory = address(new VaultV2Factory());
        console.log("VaultV2Factory", vaultV2Factory);
        address morphoVaultV1AdapterFactory = address(new MorphoVaultV1AdapterFactory());
        console.log("MorphoVaultV1AdapterFactory", morphoVaultV1AdapterFactory);
        address morphoMarketV1AdapterFactory = address(new MorphoMarketV1AdapterFactory());
        console.log("MorphoMarketV1AdapterFactory", morphoMarketV1AdapterFactory);

        vm.stopBroadcast();

        return (vaultV2Factory, morphoVaultV1AdapterFactory, morphoMarketV1AdapterFactory);
    }
}
