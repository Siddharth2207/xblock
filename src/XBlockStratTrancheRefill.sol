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

/// @dev https://etherscan.io/address/0x922D8563631B03C2c4cf817f4d18f6883AbA0109
IERC20 constant LOCK_TOKEN = IERC20(0x922D8563631B03C2c4cf817f4d18f6883AbA0109);

/// @dev https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
IERC20 constant WETH_TOKEN = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

address constant LOCK_TOKEN_HOLDER = address(0xa9A67f2748e31E2BBAB1034F067b52fa9dE27b0e);

address constant WETH_TOKEN_HOLDER = address(0x8EB8a3b98659Cce290402893d0123abb75E3ab28);

address constant LOCK_OWNER = address(0xE23B2ecD2B71133086B8e15b78a4a174ea491653);

address constant APPROVED_EOA = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

/// @dev https://etherscan.io/address/0x827179dD56d07A7eeA32e3873493835da2866976
IRouteProcessor constant ROUTE_PROCESSOR = IRouteProcessor(address(0x827179dD56d07A7eeA32e3873493835da2866976));

uint256 constant VAULT_ID = uint256(keccak256("vault"));

