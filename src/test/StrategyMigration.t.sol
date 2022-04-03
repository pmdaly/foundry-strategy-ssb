// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";
import {console} from "./utils/console.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

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
        console.log("finished harvesting");
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // migrate to a new strategy
        vm_std_cheats.prank(strategist);
        address strategyNew = deployStrategy(address(vault));
        vm_std_cheats.prank(gov);
        vault.migrateStrategy(address(strategy), address(strategyNew));
        assertRelApproxEq(IStrategy(strategyNew).estimatedTotalAssets(), _amount, DELTA);
    }
}
