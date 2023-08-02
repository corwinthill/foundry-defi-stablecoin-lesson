// SPDX-License-Identifier: MIT
/**
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin DSC;
    DSCEngine engine;
    HelperConfig config;
    address ethUSDPriceFeed;
    address btcUSDPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_DSC_TO_MINT = 3 ether;
    uint256 public constant AMOUNT_DSC_TO_BURN = 2 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (DSC, engine, config) = deployer.run();
        (ethUSDPriceFeed, btcUSDPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUSDPriceFeed);
        priceFeedAddresses.push(btcUSDPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(DSC));
    }

    address[] public tokenAddresses2;
    address[] public priceFeedAddresses2;
    address[] public actualTokenAddresses;
    address[] public actualPriceFeeds;

    function testTokenAndPriceFeedAddressArraysCorrect() public {
        tokenAddresses2.push(weth);
        tokenAddresses2.push(wbtc);
        priceFeedAddresses2.push(ethUSDPriceFeed);
        priceFeedAddresses2.push(btcUSDPriceFeed);
        actualTokenAddresses = engine.getAllowedTokens();
        actualPriceFeeds.push(engine.getPriceFeeds(tokenAddresses2[0]));
        actualPriceFeeds.push(engine.getPriceFeeds(tokenAddresses2[1]));
        assertEq(actualTokenAddresses, tokenAddresses2);
        assertEq(actualPriceFeeds, priceFeedAddresses2);
    }

    function testConstructorSetsCorrectDSCTokenAddress() public {
        address setDSC = engine.getDSCAddress();
        assertEq(setDSC, address(DSC));

    }

    //////////////////////
    // Price Feed Tests //
    //////////////////////
    function testGetUSDValue() public {
        uint256 ethAmount = 15e18;  // =30000e18 wei
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }

    function testGetTokenAmountFromUSD() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////
    function testRevertsIfCollateralZero() public { // this tests a modifier
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public { // this also tests a modifier
        ERC20Mock randomToken = new ERC20Mock("Random", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testMintRevertsWhenHealthFactorIsBroken() public depositedCollateral {
        vm.startPrank(USER); //500000000000000000
        vm.expectRevert(abi.encodeWithSelector(
            DSCEngine.DSCEngine__BreaksHealthFactor.selector, 500000000000000000));
        engine.mintDSC(2000 * AMOUNT_COLLATERAL); // Accounting for price of ether
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDSC() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    // Burn function needs an approve call for engine to transfer DSC token
    function testBurnAndGetAccountInfo() public depositedCollateralAndMintedDSC {
        vm.startPrank(USER);
        (uint256 startingDSCMinted,) = engine.getAccountInformation(USER);
        assertEq(startingDSCMinted,AMOUNT_DSC_TO_MINT);
        engine.burnDSC(AMOUNT_DSC_TO_BURN);
        (uint256 endingDSCMinted,) = engine.getAccountInformation(USER);
        uint256 endingDSCAmount = 1 ether;
        assertEq(endingDSCMinted, endingDSCAmount);
        vm.stopPrank();
    }
}
*/