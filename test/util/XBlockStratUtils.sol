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
import {
    OrderBook
} from "rain.orderbook/src/concrete/ob/OrderBook.sol"; 

import {ISubParserV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/ISubParserV2.sol";
import {OrderBookSubParser} from "rain.orderbook/src/concrete/parser/OrderBookSubParser.sol";
import {UniswapWords} from "rain.uniswap/src/concrete/UniswapWords.sol";
import {RouteProcessorOrderBookV3ArbOrderTaker} from "rain.orderbook/src/concrete/arb/RouteProcessorOrderBookV3ArbOrderTaker.sol";
import {IOrderBookV3ArbOrderTaker} from "rain.orderbook/src/interface/unstable/IOrderBookV3ArbOrderTaker.sol";
import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {
    ROUTE_PROCESSOR,
    XBLOCK_TOKEN,
    USDT_TOKEN,
    VAULT_ID,
    IOrderBookV3,
    IO,
    OrderV2,
    IO,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2,
    APPROVED_EOA,
    SafeERC20,
    IERC20
} from "src/XBlockStrat.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter/interface/IInterpreterCallerV2.sol";
import {OrderBookV3ArbOrderTakerConfigV1} from "rain.orderbook/src/abstract/OrderBookV3ArbOrderTaker.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol"; 
import "rain.uniswap/src/lib/v3/LibDeploy.sol";



contract XBlockStratUtil is Test {

    using SafeERC20 for IERC20;
    using Strings for address;
    ICloneableFactoryV2 constant CLONE_FACTORY = ICloneableFactoryV2(0x27C062142b9DF4D07191bd2127Def504DC9e9937);

    uint256 constant FORK_BLOCK_NUMBER = 19119822; 

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
    IOrderBookV3ArbOrderTaker public ARB_IMPLEMENTATION;
    IOrderBookV3ArbOrderTaker public ARB_INSTANCE;



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
        ARB_IMPLEMENTATION = new RouteProcessorOrderBookV3ArbOrderTaker();
        address ARB_INSTANCE_ADDRESS;
        {    
            bytes memory ungatedArbExpression = "";
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(ungatedArbExpression);
            bytes memory implementationData = abi.encode(address(ROUTE_PROCESSOR));
            EvaluableConfigV3 memory evaluableConfig = EvaluableConfigV3(EXPRESSION_DEPLOYER,bytecode,constants);
            OrderBookV3ArbOrderTakerConfigV1 memory cloneConfig = OrderBookV3ArbOrderTakerConfigV1(
                address(ORDERBOOK),
                evaluableConfig,
                implementationData
            );
            bytes memory encodedConfig = abi.encode(cloneConfig);

            vm.recordLogs();
            CLONE_FACTORY.clone(address(ARB_IMPLEMENTATION),encodedConfig);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            for (uint256 j = 0; j < entries.length; j++) {
            if (entries[j].topics[0] == keccak256("NewClone(address,address,address)")) {
                (,,ARB_INSTANCE_ADDRESS) = abi.decode(entries[j].data, (address, address, address));
               
            } 
        }  
        console2.log("ARB_INSTANCE_ADDRESS : ",ARB_INSTANCE_ADDRESS);
        ARB_INSTANCE = IOrderBookV3ArbOrderTaker(ARB_INSTANCE_ADDRESS);
        }
    }

    function xBlockIo() internal pure returns (IO memory) {
        return IO(address(XBLOCK_TOKEN), 18, VAULT_ID);
    }

    function usdtIo() internal pure returns (IO memory) {
        return IO(address(USDT_TOKEN), 6, VAULT_ID);
    }
    

    function getIERC20Balance(address token, address owner) internal view returns (uint256) {
        return IERC20(token).balanceOf(owner);
    }

    function giveTestAccountsTokens(IERC20 token, address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        token.safeTransfer(to, amount);
        assertEq(token.balanceOf(to), amount);
        vm.stopPrank();
    }

    function depositTokens(address depositor, IERC20 token, uint256 vaultId, uint256 amount) internal {
        vm.startPrank(depositor);
        token.safeApprove(address(ORDERBOOK), amount);
        ORDERBOOK.deposit(address(token), vaultId, amount);
        vm.stopPrank();
    }

    function placeOrder(address orderOwner, bytes memory bytecode, uint256[] memory constants, IO memory input, IO memory output)
        internal
        returns (OrderV2 memory order)
    {
        IO[] memory inputs = new IO[](1);
        inputs[0] = input;

        IO[] memory outputs = new IO[](1);
        outputs[0] = output;

        EvaluableConfigV3 memory evaluableConfig = EvaluableConfigV3(EXPRESSION_DEPLOYER, bytecode, constants);

        OrderConfigV2 memory orderConfig = OrderConfigV2(inputs, outputs, evaluableConfig, "");

        vm.startPrank(orderOwner);
        vm.recordLogs();

        (bool stateChanged) = ORDERBOOK.addOrder(orderConfig);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 3);
        (,, order,) = abi.decode(entries[2].data, (address, address, OrderV2, bytes32));
        assertEq(order.owner, orderOwner);
        assertEq(order.handleIO, true);
        assertEq(address(order.evaluable.interpreter), address(INTERPRETER));
        assertEq(address(order.evaluable.store), address(STORE));
        assertEq(stateChanged, true);
    }

    function takeOrder(OrderV2 memory order, bytes memory route) internal {
        vm.startPrank(APPROVED_EOA);

        uint256 inputIOIndex = 0;
        uint256 outputIOIndex = 0;

        TakeOrderConfigV2[] memory innerConfigs = new TakeOrderConfigV2[](1);

        innerConfigs[0] = TakeOrderConfigV2(order, inputIOIndex, outputIOIndex, new SignedContextV1[](0));
        uint256 outputTokenBalance =
            ORDERBOOK.vaultBalance(order.owner, order.validOutputs[0].token, order.validOutputs[0].vaultId);
        TakeOrdersConfigV2 memory takeOrdersConfig =
            TakeOrdersConfigV2(0, outputTokenBalance, type(uint256).max, innerConfigs, route);
        ARB_INSTANCE.arb(takeOrdersConfig, 0);
        vm.stopPrank();
    }

    function moveUniswapV3Price(
        address inputToken,
        address outputToken,
        address tokenHolder,
        uint256 amountIn,
        bytes memory encodedRoute
    ) public {
        // An External Account
        address EXTERNAL_EOA = address(0x654FEf5Fb8A1C91ad47Ba192F7AA81dd3C821427);
        {
            giveTestAccountsTokens(IERC20(inputToken), tokenHolder, EXTERNAL_EOA, amountIn);
        }
        vm.startPrank(EXTERNAL_EOA);

        IERC20(inputToken).safeApprove(address(ROUTE_PROCESSOR), amountIn);

        bytes memory decodedRoute = abi.decode(encodedRoute, (bytes));

        ROUTE_PROCESSOR.processRoute(inputToken, amountIn, outputToken, 0, EXTERNAL_EOA, decodedRoute);
        vm.stopPrank();
    } 

    function getSellOrder() internal returns(bytes memory sellOrder) {
        string[] memory inputs = new string[](9);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/TrendStrat.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "sell-order-calculate-io";
        inputs[7] = "--entrypoints";
        inputs[8] = "sell-order-handle-io";

        sellOrder = bytes.concat(getSubparserPrelude(),vm.ffi(inputs)); 
    }

    function getBuyOrder() internal returns(bytes memory buyOrder) {
        string[] memory inputs = new string[](9);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/TrendStrat.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "buy-order-calculate-io";
        inputs[7] = "--entrypoints";
        inputs[8] = "buy-order-handle-io";

        buyOrder = bytes.concat(getSubparserPrelude(),vm.ffi(inputs)); 
    }

    function getSubparserPrelude() internal returns(bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(
            string.concat(
                "using-words-from ",
                address(OB_SUPARSER).toHexString(),
                " ",
                address(UNISWAP_WORDS).toHexString()
                
            )
        );
        return RAINSTRING_OB_SUBPARSER ;
    } 

    function getEncodedBuyRoute() internal returns(bytes memory) {
        bytes memory ROUTE_PRELUDE = hex"02dAC17F958D2ee523a2206206994597C13D831ec701ffff0189eebA49E12d06A26A25F83719914f173256CE7200";
        return abi.encode(
            bytes.concat(
                ROUTE_PRELUDE,
                abi.encodePacked(address(ARB_INSTANCE))
            )
        );
    }

    function getEncodedSellRoute() internal returns(bytes memory) {
        bytes memory ROUTE_PRELUDE = hex"0225931894a86D47441213199621F1F2994e1c39Aa01ffff0189eebA49E12d06A26A25F83719914f173256CE7201";
        return abi.encode(
            bytes.concat(
                ROUTE_PRELUDE,
                abi.encodePacked(address(ARB_INSTANCE))
            )
        );
    }

}