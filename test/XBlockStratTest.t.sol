// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {console2, Test} from "forge-std/Test.sol";
import {XBlockStratUtil} from "test/util/XBlockStratUtils.sol";
import {
    XBLOCK_TOKEN, USDT_TOKEN, XBLOCK_TOKEN_HOLDER, USDT_TOKEN_HOLDER, VAULT_ID, OrderV2
} from "src/XBlockStrat.sol";

contract XBlockStratTest is XBlockStratUtil {
    address constant TEST_ORDER_OWNER = address(0x84723849238);

    function testSellOrderHappyFork() public {
        {
            uint256 depositAmount = 1000000e18;
            giveTestAccountsTokens(XBLOCK_TOKEN, XBLOCK_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, XBLOCK_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory sellOrder;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getSellOrder());
            sellOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, usdtIo(), xBlockIo());
        }
        takeOrder(sellOrder, getEncodedSellRoute());
    }

    function testBuyOrderHappyFork() public {
        {
            uint256 depositAmount = 100000e6;
            giveTestAccountsTokens(USDT_TOKEN, USDT_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, USDT_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory buyOrder;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getBuyOrder());
            buyOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, xBlockIo(), usdtIo());
        }
        vm.recordLogs();
        takeOrder(buyOrder, getEncodedBuyRoute());

        // Get Input, Output and BotBounty
        Vm.Log[] memory takeOrderEntries = vm.getRecordedLogs();
        uint256 output;
        uint256 input;
        for (uint256 j = 0; j < takeOrderEntries.length; j++) {
            if (takeOrderEntries[j].topics[0] == keccak256("Context(address,uint256[][])")) {
                (, uint256[][] memory context) = abi.decode(takeOrderEntries[j].data, (address, uint256[][]));
                input = context[3][4];
                output = context[4][4];
            }
        }
        console2.log("input : ", input);
        console2.log("output : ", output);
    }
}
