// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {IRouteProcessor} from "src/interface/IRouteProcessor.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IOrderBookV3,
    IO,
    OrderV2,
    IO,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "rain.orderbook/src/interface/unstable/IOrderBookV3.sol";

/// @dev https://etherscan.io/address/0x25931894a86D47441213199621F1F2994e1c39Aa
IERC20 constant XBLOCK_TOKEN = IERC20(0x25931894a86D47441213199621F1F2994e1c39Aa);

/// @dev https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
IERC20 constant USDT_TOKEN = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

address constant XBLOCK_TOKEN_HOLDER = address(0x480C8BCf5B02762A9E6DA110b37223CF553A462e);

address constant USDT_TOKEN_HOLDER = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);

address constant APPROVED_EOA = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

/// @dev https://etherscan.io/address/0x827179dD56d07A7eeA32e3873493835da2866976
IRouteProcessor constant ROUTE_PROCESSOR = IRouteProcessor(address(0x827179dD56d07A7eeA32e3873493835da2866976));

uint256 constant VAULT_ID = uint256(keccak256("vault"));

/// @dev Shared seed so that sells and buys have the same view of the rng.
/// `$ openssl rand -hex 32`
uint256 constant SEED = 0x844298f03374ebab272d6aea77dd06a67ca29d81adbe996adfd748ae279abd97;

/// @dev Initial tracker for calculating up down ratio.
uint256 constant TRACKER = 0x5555555555555555555555555555555555555555555555555555555555555555;

/// @dev average cooldown.
uint256 constant TARGET_COOLDOWN_18 = 1440e18;
/// @dev $166.66 recurring
uint256 constant TARGET_USDT_18 = 166e18 + 666666666666666666;
/// @dev $0.08 bounty
uint256 constant BOUNTY = 8e16;
/// @dev 1e18 constant amount
uint256 constant CONSTANT_USDT_QUOTE = 1e18;
