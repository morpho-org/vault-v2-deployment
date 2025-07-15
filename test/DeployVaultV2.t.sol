// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {console, Test} from "forge-std/Test.sol";

import {DeployMocks} from "script/DeployMocks.s.sol";
import {DeployVaultV2} from "script/DeployVaultV2.s.sol";

import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";

import {IERC4626 as IVaultV1} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Mock as AssetMock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DeployTest is Test {
    address owner;
    address curator;
    address allocator;
    address sentinel;
    IVaultV1 vaultV1;
    IVaultV2 vaultV2;
    uint256 timelockDuration;

    function setUp() public {
        vm.chainId(0);
        vaultV1 = IVaultV1(new DeployMocks().run());
        owner = makeAddr("owner");
        curator = makeAddr("curator");
        allocator = makeAddr("allocator");
        sentinel = makeAddr("sentinel");
        timelockDuration = 500;
        vaultV2 = IVaultV2(
            new DeployVaultV2().runWithArguments(owner, curator, allocator, sentinel, timelockDuration, vaultV1)
        );
    }

    function test_FullDeployment() public view {
        assertEq(vaultV2.owner(), owner, "Owner should be set correctly");
        assertEq(vaultV2.curator(), curator, "Curator should be set correctly");
        assertTrue(vaultV2.isAllocator(allocator), "Allocator should be set correctly");
        assertTrue(vaultV2.isSentinel(sentinel), "Sentinel should be set correctly");
    }

    function test_DepositAndWithdraw() public {
        address user = makeAddr("user");
        AssetMock asset = AssetMock(vaultV1.asset());
        uint256 depositAmount = 100 ether;

        asset.mint(user, depositAmount);
        assertEq(asset.balanceOf(user), depositAmount);

        vm.startPrank(user);
        asset.approve(address(vaultV2), depositAmount);
        vaultV2.deposit(depositAmount, user);
        assertEq(asset.balanceOf(user), 0);
        vm.stopPrank();

        // Sending assets to vaultV1 to simulate the yield
        uint256 giftToVaultV1 = 1 ether;
        asset.mint(address(vaultV1), giftToVaultV1);

        vm.startPrank(user);
        uint256 shares = vaultV2.balanceOf(user);
        vaultV2.redeem(shares, user, user);
        vm.stopPrank();

        assertApproxEqRel(asset.balanceOf(user), depositAmount + giftToVaultV1, 5e16); // 5% tolerance
        assertApproxEqRel(asset.balanceOf(address(vaultV1)) + 1e18, 1e18, 5e18); // 500% tolerance
    }

    function test_TimelockedFunctions() public {
        // Setup
        bytes memory idData = abi.encode("adapter", address(0x1234));
        address dummyAddr = address(0x5678);
        uint256 newFee = 1e9;
        uint256 newPenalty = 1e15;
        uint256 newCap = 1e18;

        // All selectors to test
        bytes[] memory calls = new bytes[](15);
        calls[0] = abi.encodeCall(vaultV2.setIsAllocator, (dummyAddr, true));
        calls[1] = abi.encodeCall(vaultV2.setSharesGate, (dummyAddr));
        calls[2] = abi.encodeCall(vaultV2.setReceiveAssetsGate, (dummyAddr));
        calls[3] = abi.encodeCall(vaultV2.setSendAssetsGate, (dummyAddr));
        calls[4] = abi.encodeCall(vaultV2.setIsAdapter, (dummyAddr, true));
        calls[5] = abi.encodeCall(vaultV2.abdicateSubmit, (IVaultV2.setIsAdapter.selector));
        calls[6] = abi.encodeCall(vaultV2.setPerformanceFeeRecipient, (dummyAddr));
        calls[7] = abi.encodeCall(vaultV2.setManagementFeeRecipient, (dummyAddr));
        calls[8] = abi.encodeCall(vaultV2.setPerformanceFee, (newFee));
        calls[9] = abi.encodeCall(vaultV2.setManagementFee, (newFee));
        calls[10] = abi.encodeCall(vaultV2.setVic, (dummyAddr));
        calls[11] = abi.encodeCall(vaultV2.increaseAbsoluteCap, (idData, newCap));
        calls[12] = abi.encodeCall(vaultV2.increaseRelativeCap, (idData, newCap));
        calls[13] = abi.encodeCall(vaultV2.setForceDeallocatePenalty, (dummyAddr, newPenalty));
        calls[14] = abi.encodeCall(vaultV2.setIsAllocator, (dummyAddr, false));

        bool success;
        vm.startPrank(curator);
        for (uint256 i = 0; i < calls.length; i++) {
            vaultV2.submit(calls[i]);

            assertGt(vaultV2.executableAt(calls[i]), 0);

            (success,) = address(vaultV2).call(calls[i]);
            assertFalse(success);

            vm.warp(block.timestamp + timelockDuration);
            (bool ok,) = address(vaultV2).call(calls[i]);
            assert(ok);
        }
        vm.stopPrank();
    }
}
