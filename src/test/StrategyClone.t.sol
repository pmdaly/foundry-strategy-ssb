// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";

import {IAsset} from "../interfaces/BalancerV2.sol";
import {IVault} from "../interfaces/Vault.sol";

contract StrategyClone is StrategyFixture {
    bytes32[] internal poolIds;
    IAsset[] internal addresses;

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

        Strategy.SwapSteps memory swapStepsBal = getSwapStep(true); 
        Strategy.SwapSteps memory swapStepsLdo = getSwapStep(false); 

        vm_std_cheats.prank(gov);
        clonedStrat.setKeeper(keeper);
        vm_std_cheats.prank(management);
        clonedStrat.whitelistRewards(
            tokenAddrs["BAL"], swapStepsBal
        );
        vm_std_cheats.prank(management);
        clonedStrat.whitelistRewards(
            tokenAddrs["LDO"], swapStepsLdo
        );

        vm_std_cheats.prank(gov);
        IVault(vault2).addStrategy(
            address(clonedStrat), 
            10_000,
            0,
            2 ** 256 - 1,
            1_000
        );
    }

    function getSwapStep(bool balancerSwap) public returns (Strategy.SwapSteps memory) {
        if(balancerSwap) {
            poolIds = [balWethPoolId, wethToken2PoolId];
            addresses = [
                IAsset(tokenAddrs["BAL"]),
                IAsset(tokenAddrs["WETH"]),
                IAsset(tokenAddrs["USDC"])
            ];
        } else {
            poolIds = [ldoWethPoolId, wethToken2PoolId];
            addresses = [
                IAsset(tokenAddrs["LDO"]),
                IAsset(tokenAddrs["WETH"]),
                IAsset(tokenAddrs["USDC"])
            ];
        }
        return Strategy.SwapSteps(poolIds, addresses);
    }
}
