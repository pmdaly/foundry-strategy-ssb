// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";
import {console} from "./utils/console.sol";

contract StrategyMigrationTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testMigration(uint256 _amount) public {
        console.log("setup complete!");
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        // make sure user has enough want
        vm_std_cheats.prank(user);
        tip(address(want), user, _amount);

        // Deposit to the vault and harvest
        vm_std_cheats.startPrank(user);
        want.approve(address(vault), _amount);
        vault.deposit(_amount);
        vm_std_cheats.stopPrank();
        assertEq(want.balanceOf(address(vault)), _amount);
        //skip(1);
        //vm_std_cheats.prank(gov);
        //strategy.harvest();
        //assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);
    }
}
