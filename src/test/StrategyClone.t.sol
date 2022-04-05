// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";

contract StrategyClone is StrategyFixture {
    bytes32 internal poolIds;

    function setUp() public override {
        super.setUp();
    }

    function testFailNoReinitializing() public {
        strategy.initialize(
            address(vault),
            strategist,
            rewards,
            keeper,
            balancerVault,
            balancerPool,
            maxSlippageIn,
            maxSlippageOut,
            maxSingleDeposit,
            minDepositPeriod
        );
    }

    function testClone() public {
        address vault2 = deployVault(
            tokenAddrs["USDC"],
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );
        Strategy clonedStrat = Strategy(
            strategy.clone(
                vault2, 
                strategist,
                rewards,
                keeper,
                balancerVault,
                balancerPool,
                maxSlippageIn,
                maxSlippageOut,
                maxSingleDeposit,
                minDepositPeriod
            )
        );

        vm_std_cheats.expectRevert("Strategy already initialized");
        clonedStrat.initialize(
            address(vault),
            strategist,
            rewards,
            keeper,
            balancerVault,
            balancerPool,
            maxSlippageIn,
            maxSlippageOut,
            maxSingleDeposit,
            minDepositPeriod
        );


        // place these in StrategyFixture
        poolIds = [
            0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
            0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019
        ];

        //bytes32 balWethPoolId = 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014;
        //bytes32 wethToken2PoolId = 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019;
        Strategy.SwapSteps memory swapSteps = new Strategy.SwapSteps(
            poolIds,
            [tokenAddrs["BAL"], tokenAddrs["WETH"], tokenAddrs["USDC"]]
        );

        vm_std_cheats.prank(keeper);
        clonedStrat.setKeeper(keeper);
        vm_std_cheats.prank(management);
        clonedStrat.whitelistRewards(
            tokenAddrs["BAL"], swapSteps
        );
        //vm_std_cheats.prank(management);
    }
}
