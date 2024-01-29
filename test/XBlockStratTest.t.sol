// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;
import {console2, Test} from "forge-std/Test.sol";
import {XBlockStratUtil} from "test/util/XBlockStratUtils.sol";

contract XBlockStratTest is XBlockStratUtil {

    function testStrategyExpression() public {
        setUp();
        console2.log(block.timestamp); 
    }
}