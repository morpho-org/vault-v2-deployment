// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Deposit is Script {
    function run() external  {
        vm.startBroadcast();
        IVaultV2 vaultV2 = IVaultV2(0x6f961243abb36A08A213B1Ecb6B0F67D547fe638);
        IERC20 asset = IERC20(vaultV2.asset());
        asset.approve(address(vaultV2), type(uint256).max);
        vaultV2.deposit(100, tx.origin);
        vm.stopBroadcast();
    }
}
