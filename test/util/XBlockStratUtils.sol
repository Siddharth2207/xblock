// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {console2, Test} from "forge-std/Test.sol";
import {
    ROUTE_PROCESSOR,
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
    IERC20,
    LOCK_TOKEN,
    WETH_TOKEN} from "src/XBlockStratTrancheRefill.sol";
import {
    StateNamespace,
    LibNamespace,
    FullyQualifiedNamespace
} from "rain.orderbook/lib/rain.interpreter/src/lib/ns/LibNamespace.sol";
import {LibEncodedDispatch} from "rain.orderbook/lib/rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import "src/abstract/RainContracts.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalScale.sol";

contract XBlockStratUtil is Test, RainContracts {
    using SafeERC20 for IERC20;
    using Strings for address;

    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    uint256 constant FORK_BLOCK_NUMBER = 19148722;
    uint256 constant CONTEXT_VAULT_IO_ROWS = 5;

    function selectEthFork() internal {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_ETH"));
        vm.selectFork(fork);
        vm.rollFork(FORK_BLOCK_NUMBER);
    }

    bytes32 constant ORDER_HASH = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    address constant ORDER_OWNER = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);
    address constant APPROVED_COUNTERPARTY = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);
    address constant INPUT_ADDRESS = address(LOCK_TOKEN);
    address constant OUTPUT_ADDRESS = address(WETH_TOKEN);

    address constant ETH_CLONE_FACTORY = address(0x27C062142b9DF4D07191bd2127Def504DC9e9937);

    function setUp() public {
        selectEthFork();
        deployContracts(vm,ETH_CLONE_FACTORY);
    }

    function xBlockIo() internal pure returns (IO memory) {
        return IO(address(LOCK_TOKEN), 18, VAULT_ID);
    }

    function usdtIo() internal pure returns (IO memory) {
        return IO(address(WETH_TOKEN), 6, VAULT_ID);
    }

    function getIERC20Balance(address token, address owner) internal view returns (uint256) {
        return IERC20(token).balanceOf(owner);
    }

    function getNamespace() public view returns (FullyQualifiedNamespace) {
        return LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this));
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

    function placeOrder(
        address orderOwner,
        bytes memory bytecode,
        uint256[] memory constants,
        IO memory input,
        IO memory output
    ) internal returns (OrderV2 memory order) {
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
        TakeOrdersConfigV2 memory takeOrdersConfig =
            TakeOrdersConfigV2(0, type(uint256).max, type(uint256).max, innerConfigs, route);
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

    function getTrancheRefillBuyOrder() internal returns (bytes memory trancheRefill) {
        string[] memory inputs = new string[](9);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/tranche-strat-refill.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "calculate-io-buy";
        inputs[7] = "--entrypoints";
        inputs[8] = "handle-io-buy";

        trancheRefill = bytes.concat(getSubparserPrelude(), vm.ffi(inputs));
    }

    function getTrancheRefillSellOrder() internal returns (bytes memory trancheRefill) {
        string[] memory inputs = new string[](9);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/tranche-strat-refill.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "calculate-io-sell";
        inputs[7] = "--entrypoints";
        inputs[8] = "handle-io-sell";

        trancheRefill = bytes.concat(getSubparserPrelude(), vm.ffi(inputs));
    }

    function getObSubparserPrelude() internal view returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER =
            bytes(string.concat("using-words-from ", address(OB_SUPARSER).toHexString(), " "));
        return RAINSTRING_OB_SUBPARSER;
    }

    function getSellOrder() internal returns (bytes memory sellOrder) {
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

        sellOrder = bytes.concat(getSubparserPrelude(), vm.ffi(inputs));
    }

    function getBuyOrder() internal returns (bytes memory buyOrder) {
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

        buyOrder = bytes.concat(getSubparserPrelude(), vm.ffi(inputs));
    }

    function getUdSource() internal returns (bytes memory udSource) {
        string[] memory inputs = new string[](7);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/TrendStrat.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "ud";

        udSource = bytes.concat(getSubparserPrelude(), vm.ffi(inputs));
    }

    function getSubparserPrelude() internal view returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(
            string.concat(
                "using-words-from ", address(OB_SUPARSER).toHexString(), " ", address(UNISWAP_WORDS).toHexString(), " "
            )
        );
        return RAINSTRING_OB_SUBPARSER;
    }

    function getSellOrderContext(uint256 orderHash) internal view returns (uint256[][] memory context) {
        // Sell Order Context
        context = new uint256[][](5);
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
                callingContext[1] = uint256(uint160(address(ORDERBOOK)));
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
    }

    function getBuyOrderContext(uint256 orderHash) internal view returns (uint256[][] memory context) {
        // Buy Order Context
        context = new uint256[][](5);
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
                callingContext[1] = uint256(uint160(address(ORDERBOOK)));
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
                inputsContext[0] = uint256(uint160(address(LOCK_TOKEN)));
                context[3] = inputsContext;
            }
            {
                uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
                outputsContext[0] = uint256(uint160(address(WETH_TOKEN)));
                context[4] = outputsContext;
            }
        }
    }

    function getEncodedBuyRoute() internal view returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"02dAC17F958D2ee523a2206206994597C13D831ec701ffff0189eebA49E12d06A26A25F83719914f173256CE7200";
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(ARB_INSTANCE))));
    }

    function getEncodedSellRoute() internal view returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"0225931894a86D47441213199621F1F2994e1c39Aa01ffff0189eebA49E12d06A26A25F83719914f173256CE7201";
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(ARB_INSTANCE))));
    }

    function getEncodedLockBuyRoute() internal view returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"02C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc201ffff017D45a2557bECd766A285d07a4701f5c64D716e2f00";
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(ARB_INSTANCE))));
    }

    function getEncodedLockSellRoute() internal view returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"02922D8563631B03C2c4cf817f4d18f6883AbA010901ffff017D45a2557bECd766A285d07a4701f5c64D716e2f01";
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(ARB_INSTANCE))));
    }

    function getEncodedDaiSellRoute() internal view returns (bytes memory) {
        bytes memory ROUTE_PRELUDE =
            hex"026B175474E89094C44Da98b954EedeAC495271d0F01ffff0160594a405d53811d3BC4766596EFD80fd545A27001";
        return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(address(ARB_INSTANCE))));
    }

    function decodeBits(uint256 operand, uint256 input) internal pure returns (uint256 output) {
        uint256 startBit = operand & 0xFF;
        uint256 length = (operand >> 8) & 0xFF;

        uint256 mask = (2 ** length) - 1;
        output = (input >> startBit) & mask;
    }
    
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
            if (_i == 0) {
                return "0";
            }
            uint j = _i;
            uint len;
            while (j != 0) {
                len++;
                j /= 10;
            }
            bytes memory bstr = new bytes(len);
            uint k = len;
            while (_i != 0) {
                k = k-1;
                uint8 temp = (48 + uint8(_i - _i / 10 * 10));
                bytes1 b1 = bytes1(temp);
                bstr[k] = b1;
                _i /= 10;
            }
            return string(bstr);
    }

    function eval(bytes memory rainlang) public returns (uint256[] memory) {
        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(rainlang);
        (,,address expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);
        return evalDeployedExpression(expression, ORDER_HASH);

    }

    function evalDeployedExpression(address expression, bytes32 orderHash) public returns (uint256[] memory) {
        uint256[][] memory context = buildContext(orderHash);

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(ORDERBOOK));

        (uint256[] memory stack,) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV1(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
            context,
            new uint256[](0)
        );
        return stack;
    }
    

    function buildContext(bytes32  orderHash) public pure returns (uint256[][] memory) {
        uint256[][] memory context = new uint256[][](5);

        {
            uint256[] memory baseContext = new uint256[](2);
            context[0] = baseContext;
        }
        {
            uint256[] memory callingContext = new uint256[](3);
            // order hash
            callingContext[0] = uint256(orderHash);
            // owner
            callingContext[1] = uint256(uint160(address(ORDER_OWNER)));
            // counterparty
            callingContext[2] = uint256(uint160(APPROVED_COUNTERPARTY));
            context[1] = callingContext;
        }
        {
            uint256[] memory calculationsContext = new uint256[](0);
            context[2] = calculationsContext;
        }
        {
            uint256[] memory inputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
            inputsContext[0] = uint256(uint160(address(INPUT_ADDRESS)));
            context[3] = inputsContext;
        }
        {
            uint256[] memory outputsContext = new uint256[](CONTEXT_VAULT_IO_ROWS);
            outputsContext[0] = uint256(uint160(address(OUTPUT_ADDRESS)));
            context[4] = outputsContext;
        }
        return context;
    }
}

