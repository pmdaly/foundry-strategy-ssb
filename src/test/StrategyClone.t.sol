// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";

import {IAsset} from "../interfaces/BalancerV2.sol";
import {IVault} from "../interfaces/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console} from "./utils/console.sol";

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

    function testClone(uint256 _amount) public {
        // constrain fuzz tests
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        address vault2 = deployVault(
            tokenAddrs["USDC"],
            gov,
            rewards,
            "",
            "",
            guardian,
            management
        );

        vm_std_cheats.prank(gov);
        IVault(vault2).setDepositLimit(type(uint256).max);
        vm_std_cheats.label(vault2, "Vault2");

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
        vm_std_cheats.label(address(clonedStrat), "Cloned Strat");

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

        // test_profitable_harvest
        runProfitableHarvest(
            tokenAddrs["USDC"],
            vault2,
            clonedStrat,
            _amount
        );
    }

    function getSwapStep(
        bool balancerSwap
    ) internal returns (Strategy.SwapSteps memory) {
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

    function runProfitableHarvest(
        address _token,
        address _vault, 
        Strategy _strategy,
        uint256 _amount
    ) internal {
        // make sure user has enough token
        tip(_token, user, _amount);

        // deposit to the vault
        vm_std_cheats.prank(user);
        IERC20(_token).approve(_vault, _amount);
        vm_std_cheats.prank(user);
        IVault(_vault).deposit(_amount);

        assertEq(
            IERC20(_token).balanceOf(_vault),
            _amount
        );

        // harvest 1: send funds through to the strategy
        skip(1);
        vm_std_cheats.prank(strategist);
        _strategy.harvest();
        assertRelApproxEq(_strategy.estimatedTotalAssets(), _amount, DELTA);
        
        uint256 beforePricePerShare = IVault(_vault).pricePerShare();

        // airdrop
        tip(tokenAddrs["BAL"], address(_strategy), 100 * 10 ** 18);
        tip(tokenAddrs["LDO"], address(_strategy), 100 * 10 ** 18);

        // harvest 2: realize profit
        skip(1);
        vm_std_cheats.prank(strategist);
        _strategy.harvest();
        skip(3600 * 6);
        vm_std_cheats.roll(block.number + 1);
        uint256 profit = _strategy.estimatedTotalAssets();

        assertGt(_strategy.estimatedTotalAssets() + profit, _amount);
        assertGt(IVault(_vault).pricePerShare(), beforePricePerShare);
    }
}
