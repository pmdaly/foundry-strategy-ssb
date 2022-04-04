// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";
import {console} from "./utils/console.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {IVault} from "../interfaces/Vault.sol";

contract StrategyMigrationTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testMigration(uint256 _amount) public {
        // constrain fuzz tests
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        // make sure user has enough want
        tip(address(want), user, _amount);

        // Deposit to the vault
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);

        // harvest and check asset migration
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // migrate to a new strategy
        vm_std_cheats.prank(strategist);
        address strategyNew = deployStrategy(address(vault));
        vm_std_cheats.prank(gov);
        vault.migrateStrategy(address(strategy), address(strategyNew));
        assertRelApproxEq(IStrategy(strategyNew).estimatedTotalAssets(), _amount, DELTA);
    }
    
    function testRealMigration() public {
        address liveStrat = 0xC7af91cdDDfC7c782671eFb640A4E4C4FB6352B4;
        address liveVault = IStrategy(liveStrat).vault();

        // deploy a new strategy with this vault
        vm_std_cheats.prank(strategist);
        address fixedStrategy = deployStrategy(address(liveVault));

        // migrate the live strat to the new (fixed) strat 
        vm_std_cheats.prank(gov);
        IVault(liveVault).migrateStrategy(liveStrat, fixedStrategy);
        assertGe(
            IStrategy(fixedStrategy).estimatedTotalAssets(),
            IVault(liveVault).strategies(fixedStrategy).totalDebt
        );

        // emergency exit and check harvest
        vm_std_cheats.prank(strategist);
        IStrategy(fixedStrategy).setEmergencyExit();
        vm_std_cheats.prank(strategist);
        IStrategy(fixedStrategy).harvest();
        assertEq(IStrategy(fixedStrategy).estimatedTotalAssets(), 0);
    }
}
