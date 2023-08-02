// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wethUSDPriceFeed,
        address wbtcUSDPriceFeed,
        address weth,
        address wbtc,
        uint256 deployerKey) = config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUSDPriceFeed, wbtcUSDPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin DSC = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(DSC));
        DSC.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (DSC, engine, config);
    }
}