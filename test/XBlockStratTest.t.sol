// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {console2, Test} from "forge-std/Test.sol";
import {
    XBlockStratUtil,
    IInterpreterV2,
    IInterpreterStoreV1,
    SourceIndexV2,
    StateNamespace,
    LibNamespace,
    FullyQualifiedNamespace    
} from "test/util/XBlockStratUtils.sol";
import {LibEncodedDispatch} from "rain.orderbook/lib/rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {
    XBLOCK_TOKEN,
    USDT_TOKEN,
    XBLOCK_TOKEN_HOLDER,
    USDT_TOKEN_HOLDER,
    VAULT_ID,
    OrderV2,
    TARGET_COOLDOWN_18,
    TRACKER,
    SEED
} from "src/XBlockStrat.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalScale.sol";
import "rain.orderbook/lib/rain.interpreter/src/lib/bitwise/LibCtPop.sol";

contract XBlockStratTest is XBlockStratUtil {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

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

        for(uint256 i = 0; i < 5; i++){
            vm.recordLogs();
            takeOrder(sellOrder, getEncodedSellRoute());

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
            vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);
        }


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

        for(uint256 i = 0; i < 5; i++){
            vm.recordLogs();
            takeOrder(buyOrder, getEncodedBuyRoute());

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
            vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);
        }
    }

    function testTrackSellOrderTrend() public {
        // Sell Order Context
        uint256[][] memory context = getSellOrderContext(uint256(keccak256("sellOrder")));

        // Parse and Deploy the Expression
        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getSellOrder());
        IInterpreterV2 interpreter;
        IInterpreterStoreV1 store;
        address expression;
        (interpreter, store, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

        {
            // Set initial value for the down-up ratio to be the min.
            uint256 duRatio = uint256(1e18).fixedPointDiv(11e18, Math.Rounding.Down);
            for (uint256 i = 0; i < 10; i++) {
                // Increase the price of XBLOCK
                moveUniswapV3Price(
                    address(USDT_TOKEN),
                    address(XBLOCK_TOKEN),
                    USDT_TOKEN_HOLDER,
                    1000e6,
                    getEncodedBuyRoute()
                );
                // Warp by 1 second so ensure<6> does not fail and the trade can go through the block.
                vm.warp(block.timestamp + 1);

                // Eval Order
                (uint256[] memory stack, uint256[] memory kvs) = IInterpreterV2(interpreter).eval2(
                    IInterpreterStoreV1(address(store)),
                    getNamespace(),
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                    context,
                    new uint256[](0)
                );

                // Set Kvs
                IInterpreterStoreV1(store).set(StateNamespace.wrap(0), kvs);
                // Cooldown
                vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);

                // Assert that down-up ratio is increasing when the price is increasing
                assertGe(stack[5], duRatio);
                duRatio = stack[5];
            }
        }
        {   
            // Set initial value for the down-up ratio to be the max.
            uint256 duRatio = uint256(11e18).fixedPointDiv(1e18, Math.Rounding.Down);
            for (uint256 i = 0; i < 10; i++) {
                // Decrease the price of XBLOCK
                moveUniswapV3Price(
                    address(XBLOCK_TOKEN),
                    address(USDT_TOKEN),
                    XBLOCK_TOKEN_HOLDER,
                    2000e18,
                    getEncodedSellRoute()
                );
                // Warp by 1 second so ensure<6> does not fail and the trade can go through the block.
                vm.warp(block.timestamp + 1);

                // Eval Order
                (uint256[] memory stack, uint256[] memory kvs) = IInterpreterV2(interpreter).eval2(
                    IInterpreterStoreV1(address(store)),
                    getNamespace(),
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                    context,
                    new uint256[](0)
                );

                // Set Kvs
                IInterpreterStoreV1(store).set(StateNamespace.wrap(0), kvs);
                // Cooldown
                vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);

                // Assert that down-up ratio is decreasing when the price is decreasing. 
                assertLe(stack[5], duRatio);
                duRatio = stack[5];
            }
        }
    }

    function testTrackBuyOrderTrend() public {
        // Buy Order Context
        uint256[][] memory context = getBuyOrderContext(uint256(keccak256("buyOrder")));

        // Parse and Deploy the Expression
        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getBuyOrder());
        IInterpreterV2 interpreter;
        IInterpreterStoreV1 store;
        address expression;
        (interpreter, store, expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

        {
            // Set initial value for the up-down ratio to be the max.
            uint256 udRatio = uint256(11e18).fixedPointDiv(1e18, Math.Rounding.Down);
            for (uint256 i = 0; i < 10; i++) {
                // Increase the price of XBLOCK
                moveUniswapV3Price(
                    address(USDT_TOKEN),
                    address(XBLOCK_TOKEN),
                    USDT_TOKEN_HOLDER,
                    1000e6,
                    getEncodedBuyRoute()
                );
                // Warp by 1 second so ensure<6> does not fail and the trade can go through the block.
                vm.warp(block.timestamp + 1);

                // Eval Order
                (uint256[] memory stack, uint256[] memory kvs) = IInterpreterV2(interpreter).eval2(
                    IInterpreterStoreV1(address(store)),
                    getNamespace(),
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                    context,
                    new uint256[](0)
                );

                // Set Kvs
                IInterpreterStoreV1(store).set(StateNamespace.wrap(0), kvs);
                // Cooldown
                vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);

                // Assert up-down ratio is decreasing when the price is going up.
                assertLe(stack[5], udRatio);
                // Update the last value
                udRatio = stack[5];
            }
        }
        {
            // Set initial value for the up-down ratio to be the min.
            uint256 udRatio = uint256(1e18).fixedPointDiv(11e18, Math.Rounding.Down);
            for (uint256 i = 0; i < 10; i++) {
                // Decrease the price of XBLOCK
                moveUniswapV3Price(
                    address(XBLOCK_TOKEN),
                    address(USDT_TOKEN),
                    XBLOCK_TOKEN_HOLDER,
                    2000e18,
                    getEncodedSellRoute()
                );
                // Warp by 1 second so ensure<6> does not fail and the trade can go through the block.
                vm.warp(block.timestamp + 1);

                // Eval Order
                (uint256[] memory stack, uint256[] memory kvs) = IInterpreterV2(interpreter).eval2(
                    IInterpreterStoreV1(address(store)),
                    getNamespace(),
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                    context,
                    new uint256[](0)
                );

                // Set Kvs
                IInterpreterStoreV1(store).set(StateNamespace.wrap(0), kvs);
                // Cooldown
                vm.warp(block.timestamp + TARGET_COOLDOWN_18.fixedPointMul(2e18, Math.Rounding.Down) + 1);

                // Assert up-down ratio is increasing when the price is going down.
                assertGe(stack[5], udRatio);
                // Update the last value
                udRatio = stack[5];
            }
        }
    }

    function testSellOrderTwapCheck() public {
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

        moveUniswapV3Price(
                address(USDT_TOKEN),
                address(XBLOCK_TOKEN),
                USDT_TOKEN_HOLDER,
                1000e6,
                getEncodedBuyRoute()
        );

        // Revert if the price changes within the same block time
        vm.expectRevert(bytes("OLD"));
        takeOrder(sellOrder, getEncodedSellRoute());

        // Increase the block time and check if the call succeeds
        vm.warp(block.timestamp + 1);
        takeOrder(sellOrder, getEncodedSellRoute());
    
    }

    function testBuyOrderTwapCheck() public {
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
        
        moveUniswapV3Price(
                    address(XBLOCK_TOKEN),
                    address(USDT_TOKEN),
                    XBLOCK_TOKEN_HOLDER,
                    2000e18,
                    getEncodedSellRoute()
        );

        // Revert if the price changes within the same block time 
        vm.expectRevert(bytes("OLD"));
        takeOrder(buyOrder, getEncodedBuyRoute());

        // Increase the block time and check if the call succeeds
        vm.warp(block.timestamp + 1);
        takeOrder(buyOrder, getEncodedBuyRoute());

    }

    function testUdRatio(uint256[] memory valueInputs) public {
        // Intial Tracker
        uint256 tracker = TRACKER;
        // Intial value
        uint256 lastValue = 0;

        // Parser and Deploy expression
        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getUdSource());
        (IInterpreterV2 interpreter, IInterpreterStoreV1 store, address expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

        uint256[][] memory context = new uint256[][](0);
        uint256[] memory inputs = new uint256[](2);

        for (uint256 i = 0; i < valueInputs.length; i++) {
            uint256 currentValue = valueInputs[i];
            inputs[0] = currentValue;
            inputs[1] = SEED;

            // Eval UD expression
            (uint256[] memory stack, uint256[] memory kvs) = INTERPRETER.eval2(
                    store,
                    getNamespace(),
                    LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                    context,
                    inputs
            );

            {
                // Update local tracker and calculate up-down ratio
                tracker = (tracker << 1) | (currentValue > lastValue ? 1 : 0);
                uint256 tracker10 = decodeBits(0x010A00, tracker);
                uint256 upCount = LibCtPop.ctpop(tracker10);
                uint256 downCount = 10 - upCount;
                uint256 ups = upCount == 0 ? 1 : upCount;
                uint256 downs = downCount == 0 ? 1 : downCount;

                // Check ups,dpwns.
                assertEq(stack[1], ups);
                assertEq(stack[0], downs);

                // Update Store
                store.set(StateNamespace.wrap(0), kvs);
            }

            // Update last value
            lastValue = currentValue;
        }
    } 


}
