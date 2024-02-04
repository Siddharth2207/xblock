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
    DAI_TOKEN
} from "src/XBlockStratTrancheRefill.sol";
import {LibEncodedDispatch} from "rain.orderbook/lib/rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";

interface IHoudiniSwapToken { 
    function launch() external;
    function setAutomatedMarketMakerPair(address account,bool value) external;
}

contract XBlockTrancheStratRefillTest is XBlockStratUtil { 

    using SafeERC20 for IERC20;
    address constant TEST_ORDER_OWNER = address(0x84723849238); 

    function launchLockToken(address arbContract) public { 
        vm.startPrank(LOCK_OWNER);
        IHoudiniSwapToken(address(LOCK_TOKEN)).launch();
        IHoudiniSwapToken(address(LOCK_TOKEN)).setAutomatedMarketMakerPair(arbContract,true);

        vm.stopPrank();
    }

    function lockIo() internal pure returns (IO memory) {
        return IO(address(LOCK_TOKEN), 18, VAULT_ID);
    }

    function wethIo() internal pure returns (IO memory) {
        return IO(address(WETH_TOKEN), 18, VAULT_ID);
    }

    function xtestTrancheRefillBuyOrder() public {

        launchLockToken(address(ARB_INSTANCE)); 
        {
            uint256 depositAmount = 1e18;
            giveTestAccountsTokens(WETH_TOKEN, WETH_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, WETH_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory trancheOrder;  
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillBuyOrder());
            trancheOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, lockIo(), wethIo());
        }

        takeOrder(trancheOrder, getEncodedLockBuyRoute());

        
    }

    function xtestTrancheRefillSellOrder() public {

        launchLockToken(address(ARB_INSTANCE)); 
        {
            uint256 depositAmount = 100e18;
            giveTestAccountsTokens(LOCK_TOKEN, LOCK_TOKEN_HOLDER, TEST_ORDER_OWNER, depositAmount);
            depositTokens(TEST_ORDER_OWNER, LOCK_TOKEN, VAULT_ID, depositAmount);
        }
        OrderV2 memory trancheOrder;  
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillSellOrder());
            trancheOrder = placeOrder(TEST_ORDER_OWNER, bytecode, constants, wethIo(), lockIo());
        }

        takeOrder(trancheOrder, getEncodedLockSellRoute());
    } 

    function testSellOrderMonteCarlo() public { 

          
        uint256 trancheSpaceKey = 34265990357791727081379356947724195239819740813626325105305338534729402249237;

        uint256 orderHash = 12345;
        uint256[][] memory context = new uint256[][](5);
        {
            {
                uint256[] memory baseContext = new uint256[](2);
                context[0] = baseContext;
            }
            {
                uint256[] memory callingContext = new uint256[](3);
                // order hash
                callingContext[0] = orderHash;
                // owner
                callingContext[1] = uint256(uint160(address(this)));
                // counterparty
                callingContext[2] = uint256(uint160(address(ARB_INSTANCE)));
                context[1] = callingContext;
            }
            {
                uint256[] memory calculationsContext = new uint256[](0);
                context[2] = calculationsContext;
            }
            {
                uint256[] memory inputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                inputsContext[0] = uint256(uint160(address(WETH_TOKEN)));
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(address(LOCK_TOKEN)));
                context[4] = outputsContext;
            }
        }
        IInterpreterV2 interpreter;
        IInterpreterStoreV1 store;
        address expression;
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(getTrancheRefillSellOrder());
            (interpreter,store,expression,) 
                = EXPRESSION_DEPLOYER.deployExpression2(bytecode,constants);
        }

        uint256 trancheSpacePerSecond = 11574074e14; 

        for(uint256 i = 1; i <= 2 ; i ++){ 
            uint256 trancheSpace =  i * trancheSpacePerSecond;

            vm.mockCall(
                address(store),
                abi.encodeWithSelector(store.get.selector,getNamespace(),trancheSpaceKey),
                abi.encode(trancheSpace)
            );

            (uint256[] memory stack,) = interpreter.eval2(
                store,
                getNamespace(),
                LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
                context,
                new uint256[](0)
            ); 
            
            console2.log("%s,%s,%s",trancheSpace,stack[0],stack[1]);  
        }
    }
}
