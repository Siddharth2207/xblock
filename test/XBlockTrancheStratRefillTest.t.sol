// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {console2, Test} from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import {
    XBlockStratUtil,
    IInterpreterV2,
    IInterpreterStoreV1,
    SourceIndexV2,
    StateNamespace,
    LibNamespace,
    FullyQualifiedNamespace
} from "test/util/XBlockStratUtils.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter/interface/IInterpreterCallerV2.sol";
import {
    LOCK_TOKEN,
    WETH_TOKEN,
    LOCK_TOKEN_HOLDER,
    WETH_TOKEN_HOLDER,
    VAULT_ID,
    OrderV2,
    LOCK_OWNER,
    SafeERC20,
    IERC20,
    IO,
    DAI_TOKEN_HOLDER,
    DAI_TOKEN,
    APPROVED_EOA,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "src/XBlockStratTrancheRefill.sol";
import {LibOrder} from "rain.orderbook/src/lib/LibOrder.sol";

interface IHoudiniSwapToken {
    function launch() external;
    function setAutomatedMarketMakerPair(address account, bool value) external;
}

contract XBlockTrancheStratRefillTest is XBlockStratUtil {
    using SafeERC20 for IERC20;
    using LibOrder for OrderV2;

    address constant TEST_ORDER_OWNER = address(0x84723849238);

    function launchLockToken() public {
        vm.startPrank(LOCK_OWNER);
        IHoudiniSwapToken(address(LOCK_TOKEN)).launch();
        vm.stopPrank();
    }

    function lockIo() internal pure returns (IO memory) {
        return IO(address(LOCK_TOKEN), 18, VAULT_ID);
    }

    function wethIo() internal pure returns (IO memory) {
        return IO(address(WETH_TOKEN), 18, VAULT_ID);
    }

    function testTrancheRefillTakeBuyOrder() public {
        string memory file = './test/csvs/tranche-amount-io.csv';
        if (vm.exists(file)) vm.removeFile(file);

        vm.writeLine(file, string.concat(
            "Timestamp",
            ",",
            "Amount",
            ",",
            "Price"
        ));

        launchLockToken();
        
        uint256 maxAmountPerTakeOrder = type(uint256).max;
        {   
            uint256 depositAmount = type(uint256).max;
            deal(address(WETH_TOKEN), TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, WETH_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory trancheOrder;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillBuyOrder());
            trancheOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, lockIo(), wethIo());
        }

        uint256 inputIOIndex = 0;
        uint256 outputIOIndex = 0;

        TakeOrderConfigV2[] memory innerConfigs = new TakeOrderConfigV2[](1);

        innerConfigs[0] = TakeOrderConfigV2(trancheOrder, inputIOIndex, outputIOIndex, new SignedContextV1[](0));
        TakeOrdersConfigV2 memory takeOrdersConfig =
            TakeOrdersConfigV2(0, maxAmountPerTakeOrder, type(uint256).max, innerConfigs, "");

        deal(address(LOCK_TOKEN), APPROVED_EOA, type(uint256).max);
        vm.startPrank(APPROVED_EOA);
        IERC20(address(LOCK_TOKEN)).safeApprove(address(ORDERBOOK), type(uint256).max);
        
        for(uint256 i = 0; i < 100; i++){
            vm.recordLogs();
            ORDERBOOK.takeOrders(takeOrdersConfig);
            Vm.Log[] memory entries = vm.getRecordedLogs();

            uint256 amount;
            uint256 ratio;

            for (uint256 j = 0; j < entries.length; j++) {
                if (entries[j].topics[0] == keccak256("Context(address,uint256[][])")) {
                    (, uint256[][] memory context) = abi.decode(entries[j].data, (address, uint256[][]));
                    amount = context[2][0];
                    ratio = context[2][1];
                }
            }

            uint256 time = block.timestamp + 60 * 4; // moving forward 4 minutes

            string memory line = string.concat(
                    uint2str(time),
                    ",",
                    uint2str(amount),
                    ",",
                    uint2str(ratio)
            );

            vm.writeLine(file, line);

            vm.warp(time);
        }

        vm.stopPrank();
    }

    function testTrancheRefillBuyOrderHappyFork() public {
        launchLockToken();
        {
            uint256 depositAmount = 1e18;
            giveTestAccountsTokens(WETH_TOKEN, WETH_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, WETH_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory trancheOrder;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillBuyOrder());
            trancheOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, xBlockIo(), wethIo());
        }

        takeOrder(trancheOrder, getEncodedLockBuyRoute());
    }

    function testTrancheRefillSellOrderHappyFork() public {
        launchLockToken();
        {
            uint256 depositAmount = 3000e18;
            giveTestAccountsTokens(LOCK_TOKEN, LOCK_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, LOCK_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory trancheOrder;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillSellOrder());
            trancheOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, wethIo(), xBlockIo());
        }
        moveUniswapV3Price(
            address(WETH_TOKEN),
            address(LOCK_TOKEN),
            WETH_TOKEN_HOLDER,
            10000e18,
            getEncodedLockBuyRoute()
        );
        takeOrder(trancheOrder, getEncodedLockSellRoute());
    }
}