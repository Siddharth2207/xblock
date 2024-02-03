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
    IO
} from "src/XBlockStratTrancheRefill.sol";

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

    function testTrancheRefillBuyOrder() public {

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

    function testTrancheRefillSellOrder() public {

        launchLockToken(address(ARB_INSTANCE)); 
        {
            uint256 depositAmount = 1e18;
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
    
}