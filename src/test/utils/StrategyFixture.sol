// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVault} from "../../interfaces/Vault.sol";
import {console} from "./console.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {Strategy} from "../../Strategy.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant vaultArtifact = "artifacts/Vault.json";

// Base fixture deploying Vault
contract StrategyFixture is ExtendedDSTest, stdCheats {
    using SafeERC20 for IERC20;

    // we use custom names that are unlikely to cause collisions so this contract
    // can be inherited easily
    // TODO: see if theres a better way to use this
    Vm public constant vm_std_cheats =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IVault public vault;
    Strategy public strategy;
    IERC20 public weth;
    IERC20 public want;

    mapping(string => address) public tokenAddrs;
    mapping(string => uint256) public tokenPrices;
    mapping(string => bytes32) public tokenPools;

    address public gov = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address public user = address(1);
    address public whale = address(2);
    address public rewards = address(3);
    address public guardian = address(4);
    address public management = address(5);
    address public strategist = address(6);
    address public keeper = address(7);

    // SSB test contstants
    address public balWhale = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public ldoWhale = 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c;

    uint256 public minFuzzAmt;
    // @dev maximum amount of want tokens deposited based on @maxDollarNotional
    uint256 public maxFuzzAmt;
    // @dev maximum dollar amount of tokens to be deposited
    uint256 public maxDollarNotional = 1_000_000;
    // @dev maximum dollar amount of tokens for single large amount
    uint256 public bigDollarNotional = 49_000_000;
    // @dev used for non-fuzz tests to test large amounts
    uint256 public bigAmount;

    // Used for integer approximation
    uint256 public constant DELTA = 10**3;

    // Strategy constants
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public balancerPool = 0x06Df3b2bbB68adc8B0e302443692037ED9f91b42;
    uint256 public maxSlippageIn = 5;
    uint256 public maxSlippageOut = 5;
    uint256 public maxSingleDeposit = 100_000;
    uint256 public minDepositPeriod = 2 * 60 * 60;

    function setUp() public virtual {
        _setTokenAddrs();
        _setTokenPrices();
        _setTokenPools();

        // Choose a token from the tokenAddrs mapping, see _setTokenAddrs for options
        // from SSB
        // token = usdc
        // token2 = dai
        string memory token = "USDC";
        weth = IERC20(tokenAddrs["WETH"]);
        want = IERC20(tokenAddrs[token]);

        deployVaultAndStrategy(
            address(want),
            gov,
            rewards,
            "",
            "",
            guardian,
            management,
            keeper,
            strategist
        );

        minFuzzAmt = 10**vault.decimals() / 10;
        maxFuzzAmt =
            uint256(maxDollarNotional / tokenPrices[token]) *
            10**vault.decimals();
        bigAmount =
            uint256(bigDollarNotional / tokenPrices[token]) *
            10**vault.decimals();

        // add more labels to make your traces readable
        vm_std_cheats.label(address(vault), "Vault");
        vm_std_cheats.label(address(strategy), "Strategy");
        vm_std_cheats.label(address(want), "Want");
        vm_std_cheats.label(gov, "Gov");
        vm_std_cheats.label(user, "User");
        vm_std_cheats.label(whale, "Whale");
        vm_std_cheats.label(rewards, "Rewards");
        vm_std_cheats.label(guardian, "Guardian");
        vm_std_cheats.label(management, "Management");
        vm_std_cheats.label(strategist, "Strategist");
        vm_std_cheats.label(keeper, "Keeper");

        // do here additional setup
        vm_std_cheats.prank(gov);
        vault.setDepositLimit(type(uint256).max);
    }

    // Deploys a vault
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm_std_cheats.prank(gov);
        address _vault = deployCode(vaultArtifact);
        vault = IVault(_vault);

        vm_std_cheats.prank(gov);
        vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        return address(vault);
    }

    // Deploys a strategy
    function deployStrategy(address _vault) public returns (address) {
        Strategy _strategy = new Strategy(
            _vault,
            balancerVault,
            balancerPool,
            maxSlippageIn,
            maxSlippageOut,
            maxSingleDeposit,
            minDepositPeriod
        );
        return address(_strategy);
    }

    // Deploys a vault and strategy attached to vault
    function deployVaultAndStrategy(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management,
        address _keeper,
        address _strategist
    ) public returns (address _vault, address _strategy) {
        vm_std_cheats.prank(gov);
        _vault = deployCode(vaultArtifact);
        vault = IVault(_vault);

        vm_std_cheats.prank(gov);
        vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        vm_std_cheats.prank(_strategist);
        _strategy = deployStrategy(_vault);
        strategy = Strategy(payable(_strategy));

        vm_std_cheats.prank(_strategist);
        strategy.setKeeper(_keeper);

        vm_std_cheats.prank(gov);
        vault.addStrategy(_strategy, 10_000, 0, type(uint256).max, 1_000);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["BAL"] = 0xba100000625a3754423978a60c9317c58a424e3D;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["LDO"] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    }

    function _setTokenPools() internal {
        tokenPools["WETH_USDC_POOL"] = 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019;
        tokenPools["WETH_DAI_POOL"] = 0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a;
        tokenPools["BAL_WETH_POOL"] = 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014;
        tokenPools["LDO_WETH_POOL"] = 0xbf96189eee9357a95c7719f4f5047f76bde804e5000200000000000000000087;
    }
    
    function _setTokenPrices() internal {
        tokenPrices["WBTC"] = 60_000;
        tokenPrices["YFI"] = 35_000;
        tokenPrices["WETH"] = 4_000;
        tokenPrices["BAL"] = 20;
        tokenPrices["LINK"] = 15;
        tokenPrices["LDO"] = 4;
        tokenPrices["USDT"] = 1;
        tokenPrices["USDC"] = 1;
        tokenPrices["DAI"] = 1;
    }
}
