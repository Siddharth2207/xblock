// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;
import {console2, Test} from "forge-std/Test.sol";
import {RainterpreterParserNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterParserNPE2.sol";
import {RainterpreterStoreNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterStoreNPE2.sol";
import {RainterpreterNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterNPE2.sol";
import {RainterpreterExpressionDeployerNPE2,RainterpreterExpressionDeployerNPE2ConstructionConfig} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterExpressionDeployerNPE2.sol"; 
import {IParserV1} from "rain.orderbook/lib/rain.interpreter/src/interface/IParserV1.sol";
import {IInterpreterStoreV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IInterpreterStoreV2.sol";
import {IInterpreterV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IInterpreterV2.sol";
import {IExpressionDeployerV3} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IExpressionDeployerV3.sol";
import {IOrderBookV3, OrderBook} from "rain.orderbook/src/concrete/ob/OrderBook.sol";
import {ISubParserV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/ISubParserV2.sol";
import {OrderBookSubParser} from "rain.orderbook/src/concrete/parser/OrderBookSubParser.sol";
import {UniswapWords} from "rain.uniswap/src/concrete/UniswapWords.sol";
// import "view-quoter-v3/contracts/Quoter.sol";
import "rain.uniswap/src/lib/v3/LibDeploy.sol";


contract XBlockStratUtil is Test {

    uint256 constant FORK_BLOCK_NUMBER = 19113518; 

    function selectEthFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_ETH"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    } 

    IParserV1 public PARSER;
    IInterpreterV2 public INTERPRETER;
    IInterpreterStoreV2 public STORE;
    IExpressionDeployerV3 public EXPRESSION_DEPLOYER;
    IOrderBookV3 public ORDERBOOK;
    ISubParserV2 public OB_SUPARSER;
    ISubParserV2 public UNISWAP_WORDS;


    function setUp() public {
        selectEthFork();
        PARSER = new RainterpreterParserNPE2(); 
        STORE = new RainterpreterStoreNPE2();
        INTERPRETER = new RainterpreterNPE2();
        

        bytes memory constructionMeta = vm.readFileBinary("lib/rain.orderbook/lib/rain.interpreter/meta/RainterpreterExpressionDeployerNPE2.rain.meta");

        EXPRESSION_DEPLOYER = new RainterpreterExpressionDeployerNPE2(
            RainterpreterExpressionDeployerNPE2ConstructionConfig(
                address(INTERPRETER), address(STORE), address(PARSER), constructionMeta
            )
        );

        ORDERBOOK = new OrderBook();
        OB_SUPARSER = new OrderBookSubParser();
        UNISWAP_WORDS = LibDeploy.newUniswapWords(vm); 

    }

}