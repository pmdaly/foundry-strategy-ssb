// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";
import {console} from "./utils/console.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {IVault} from "../interfaces/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyShutdown is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testVaultShutdownCanWithdraw(uint256 _amount) public {
        // constrain fuzz tests
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        // make sure user has enough want
        tip(address(want), user, _amount);

        // Deposit to the vault
        vm_std_cheats.prank(user);
        want.approve(address(vault), _amount);
        vm_std_cheats.prank(user);
        vault.deposit(_amount);
        assertEq(want.balanceOf(address(vault)), _amount);

        if (want.balanceOf(user) > 0) {
            vm_std_cheats.prank(user);
            want.transfer(address(0), want.balanceOf(user));
        }

        // harvest and check asset migration
        skip(3600 * 7);
        // do we need to mine here as the brownie version does?
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);

        // set emergency shutdown, withdraw and check balance
        vm_std_cheats.prank(gov);
        vault.setEmergencyShutdown(true);
        vm_std_cheats.prank(user);
        vault.withdraw();
        assertRelApproxEq(want.balanceOf(user), _amount, DELTA);
    }
}
