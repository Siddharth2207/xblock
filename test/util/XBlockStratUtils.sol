// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;
import {console2, Test} from "forge-std/Test.sol";
import {RainterpreterParserNPE2} from "lib/rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterParserNPE2.sol"; 
import {IParserV1} from "lib/rain.orderbook/lib/rain.interpreter/src/interface/IParserV1.sol";

contract XBlockStratUtil is Test {

    uint256 constant FORK_BLOCK_NUMBER = 19113518; 

    function selectEthFork() internal {
        uint256 fork = vm.createFork("https://eth.llamarpc.com");
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    } 

    IParserV1 public PARSER;

    function setUp() public {
        selectEthFork();
        PARSER = new RainterpreterParserNPE2(); 
    }

}