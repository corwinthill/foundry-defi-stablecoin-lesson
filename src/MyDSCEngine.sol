// // SPDX-License-Identifier: MIT

// // This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// // Layout of Contract:
// // version
// // imports
// // errors
// // interfaces, libraries, contracts
// // Type declarations
// // State variables
// // Events
// // Modifiers
// // Functions

// // Layout of Functions:
// // constructor
// // receive function (if exists)
// // fallback function (if exists)
// // external
// // public
// // internal
// // private
// // view & pure functions

// /**
// pragma solidity ^0.8.18;

// import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import {console} from "forge-std/console.sol";

// /**
//  * @title DSCEngine
//  * @author Corwin Hill
//  *
//  * The system is designed to be as minimal as possible, and have the tokens
//  * maintain a 1 token == $1 peg.
//  * This stablecoin has the properties:
//  * - Exogenous Collatteral
//  * - Dollar Pegged
//  * - Algorithmically Stable
//  *
//  * It is similar to DAI if DAI had no governance, no fees, and was only backed
//  * by wETH and wBTC.
//  *
//  * Our DSC system should always be "overcollateralized". At no point, should the
//  * value of all collateral <= the $ backed value of all the DSC.
//  *
//  * @notice This contract is the core of the DSC System. it handles all the logic
//  * for minting and redeeming DEC, as well as depositing and withdrawing collateral.
//  * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
//  */

// contract DSCEngine is ReentrancyGuard {
//     ///////////////////////
//     //      Errors       //
//     ///////////////////////
//     error DSCEngine__NeedsMoreThanZero();
//     error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
//     error DSCEngine__NotAllowedToken();
//     error DSCEngine__TransferFailed();
//     error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
//     error DSCEngine__MintFailed();
//     error DSCEngine__HealthFactorOk();
//     error DSCEngine__HealthFactorNotImproved();

//     ///////////////////////
//     //  State Varaibles  //
//     ///////////////////////
//     uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
//     uint256 private constant PRECISION = 1e18;
//     uint256 private constant LIQUIDATION_THRESHOLD = 50;
//     uint256 private constant LIQUIDATION_PRECISION = 100;
//     uint256 private constant MIN_HEALTH_FACTOR = 1e18;
//     uint256 private constant LIQUIDATOR_BONUS = 10;
    
//     mapping(address token => address priceFeed) private s_priceFeeds;
//     mapping(address user => mapping(address token => uint256 amount))
//         private s_collateralDeposited;
//     mapping(address user => uint256 amountDSCMinted) private s_DSCMinted;
//     address[] private s_collateralTokens;

//     DecentralizedStableCoin private immutable i_DSC;

//     ///////////////////////
//     //      Events       //
//     ///////////////////////
//     event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
//     event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);

//     ///////////////////////
//     //     Modifiers     //
//     ///////////////////////
//     modifier moreThanZero(uint256 amount) {
//         if (amount == 0) {
//             revert DSCEngine__NeedsMoreThanZero();
//         }
//         _;
//     }

//     modifier isAllowedToken(address token) {
//         if(s_priceFeeds[token] == address(0)) {
//             revert DSCEngine__NotAllowedToken();
//         }
//         _;
//     }
    
//     ///////////////////////
//     //     Functions     //
//     ///////////////////////
//     constructor(
//         address[] memory tokenAddresses,
//         address[] memory priceFeedAddresses,
//         address DSCAddress
//     ) {
//         if (tokenAddresses.length != priceFeedAddresses.length) {
//             revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
//         }
//         for (uint256 i = 0; i < tokenAddresses.length; i++) {
//             s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
//             s_collateralTokens.push(tokenAddresses[i]);
//         }
//         i_DSC = DecentralizedStableCoin(DSCAddress);
//     }

//     ////////////////////////
//     // External Functions //
//     ////////////////////////
    
//     /**
//      * @param tokenCollateralAddress - The address of the token to deposit
//      * as collateral
//      * @param amountCollateral - The amountt of collateral to deposit
//      * @param amountDSCToMint - The amount of DSC to mint
//      * @notice This function will deposit your collateral and mintt DSC in
//      * one transaction
//      */
//     function depositCollateralAndMintDSC(
//         address tokenCollateralAddress,
//         uint256 amountCollateral,
//         uint256 amountDSCToMint
//     ) external {
//         depositCollateral(tokenCollateralAddress, amountCollateral);
//         mintDSC(amountDSCToMint);
//     }

//     /**
//      * @notice Follows CEI
//      * @param tokenCollateralAddress - The address of the token to deposit
//      * as collateral
//      * @param amountCollateral - The amount of collateral to deposit
//      */

//     function depositCollateral(
//         address tokenCollateralAddress,
//         uint256 amountCollateral
//     )
//         public
//         moreThanZero(amountCollateral)
//         isAllowedToken(tokenCollateralAddress)
//         nonReentrant
//     {
//         s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
//         emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
//         bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
//         if (!success) {
//             revert DSCEngine__TransferFailed();
//         }
//     }

//     /**
//      * @param tokenCollateralAddress - The token collateral address to redeem
//      * @param amountCollateral - The amount of collateral to redeem
//      * @param amountDSCToBurn - The amount of DSC to burn
//      * This function burns DSC and redeems underlying collateral in one transaction
//      */
//     function redeemCollateralForDSC(
//         address tokenCollateralAddress,
//         uint256 amountCollateral,
//         uint256 amountDSCToBurn
//     ) external {
//         burnDSC(amountDSCToBurn);
//         redeemCollateral(tokenCollateralAddress, amountCollateral);
//     }

//     function redeemCollateral(
//         address tokenCollateralAddress,
//         uint256 amountCollateral)
//         public
//         moreThanZero(amountCollateral)
//         nonReentrant 
//     {
//         _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     /**
//      * @notice Follows CEI
//      * @param amountDSCToMint - The amount of DSC to mint
//      * @notice They must have more collateral value than the minimum threshold
//      */
//     function mintDSC(uint256 amountDSCToMint)
//         public
//         moreThanZero(amountDSCToMint)
//         nonReentrant
//     {
//         s_DSCMinted[msg.sender] += amountDSCToMint;
//         _revertIfHealthFactorIsBroken(msg.sender);
//         bool minted = i_DSC.mint(msg.sender, amountDSCToMint);
//         if (!minted) {
//             revert DSCEngine__MintFailed();
//         }
//     }

//     function burnDSC(uint256 amount) public moreThanZero(amount) {
//         _burnDSC(amount, msg.sender, msg.sender);
//         _revertIfHealthFactorIsBroken(msg.sender); // Should be unnecessary
//     }

//     /**
//      * @param collateral - The ERC20 collateral address to liquidate from user
//      * @param user - The user who has broken the health factor. ie HF < MIN_HF
//      * @param debtToCover - The amount of DSC you want to burn to improve
//      * the users health factor
//      * @notice You can partially liquidate a user.
//      * @notice You will get a liquidation bonus for taking the users funds
//      * @notice This function working assumes the protocol will be roughly
//      * 200% overcollateralized in order for this to work.
//      * @notice A known bug would be if the protocol were 100% or less
//      * collateralized, then we wouldn't be able to incentivize liquidators.
//      * ie. A token price plummets before anyone can liquidate
//      */
//     function liquidate(address collateral, address user, uint256 debtToCover)
//         external moreThanZero(debtToCover) nonReentrant
//     {
//         uint256 startingUserHealthFactor = _healthFactor(user);
//         if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
//             revert DSCEngine__HealthFactorOk();
//         }
//         uint256 tokenAmountFromDebtCovered =
//         getTokenAmountFromUSD(collateral, debtToCover);
//         uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / 
//         LIQUIDATION_PRECISION;
//         uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
//         _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
//         _burnDSC(debtToCover, user, msg.sender);
//         uint256 endingUserHealthFactor = _healthFactor(user);
//         if (endingUserHealthFactor <= startingUserHealthFactor) {
//             revert DSCEngine__HealthFactorNotImproved();
//         }
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function getHealthFactor() external view {}

//     /////////////////////////////////////////
//     // Private and Internal View Functions //
//     /////////////////////////////////////////

//     /**
//      * @dev Low-level internal function, do not call unless the function calling it
//      * is checking for health factors being broken
//      */
//     function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
//         s_DSCMinted[onBehalfOf] -= amountDSCToBurn;
//         bool success = i_DSC.transferFrom(dscFrom, address(this), amountDSCToBurn);
//         if (!success) {
//             revert DSCEngine__TransferFailed();
//         }
//         i_DSC.burn(amountDSCToBurn);
//     }
    
//     function _redeemCollateral(
//         address from,
//         address to,
//         address tokenCollateralAddress,
//         uint256 amountCollateral
//     ) private {
//         s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
//         emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
//         bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
//         if (!success) {
//             revert DSCEngine__TransferFailed();
//         }
//     }
    
//     function _getAccountInformation(address user) private view
//         returns(uint256 totalDSCMinted, uint256 collateralValueInUSD)
//     {
//         totalDSCMinted = s_DSCMinted[user];
//         collateralValueInUSD = getAccountCollateralValue(user);
//     }

//     /**
//      * Returns how close to liquidation a user is
//      * If a user goes below 1, then they can get liquidated
//      */
//     function _healthFactor(address user) private view returns(uint256) {
//         (uint256 totalDSCMinted, uint256 collateralValueInUSD) =
//         _getAccountInformation(user);
//         uint256 collateralAdjustedForThreshold = 
//         (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
//         return ((collateralAdjustedForThreshold * PRECISION) / totalDSCMinted);
//     }
    
//     function _revertIfHealthFactorIsBroken(address user) internal view {
//         uint256 userHealthFactor = _healthFactor(user);
//         if (userHealthFactor < MIN_HEALTH_FACTOR) {
//             revert DSCEngine__BreaksHealthFactor(userHealthFactor);
//         }
//     }

//     ////////////////////////////////////////
//     // Public and External View Functions //
//     ////////////////////////////////////////
//     function getTokenAmountFromUSD(address token, uint256 usdAmountInWei)
//     public view returns(uint256) {
//         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
//         (,int256 price,,,) = priceFeed.latestRoundData();
//         return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
//     }
    
//     function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUSD) {
//         for (uint256 i = 0; i < s_collateralTokens.length; i++) {
//             address token = s_collateralTokens[i];
//             uint256 amount = s_collateralDeposited[user][token];
//             totalCollateralValueInUSD += getUSDValue(token, amount);
//         }
//         return totalCollateralValueInUSD;
//     }

//     function getUSDValue(address token, uint256 amount) public view returns(uint256) {
//         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
//         (,int256 price,,,) = priceFeed.latestRoundData();
//         return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
//     }

//     function getAccountInformation(address user) external view
//     returns(uint256 totalDSCMinted, uint256 collateralValueInUSD) {
//         (totalDSCMinted, collateralValueInUSD) = _getAccountInformation(user);
//     }

//     function getAllowedTokens() public view returns(address[] memory) {
//         return(s_collateralTokens);
//     }
    
//     /**
//     function getPriceFeeds() public view returns(address[] memory) {
//         address[] memory priceFeeds;
//         console.log(s_collateralTokens.length);
//         for (uint256 i = 0; i < s_collateralTokens.length; i++) {
//             priceFeeds[i] = (s_priceFeeds[s_collateralTokens[i]]);
//         }
//         return priceFeeds;
//     }
//     */

//     function getPriceFeeds(address token) public view returns(address pf) {
//         return s_priceFeeds[token];
//     }

//     function getDSCAddress() public view returns(address dsc) {
//         return address(i_DSC);
//     }
// }
