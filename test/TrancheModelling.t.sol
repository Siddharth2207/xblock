// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Script} from "forge-std/Script.sol";
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
    LOCK_TOKEN,
    LOCK_TOKEN_HOLDER,
    VAULT_ID,
    OrderV2,
    LibTrancheRefillOrders
} from "src/XBlockStratTrancheRefill.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import "rain.orderbook/lib/rain.math.fixedpoint/src/lib/LibFixedPointDecimalScale.sol";
import "rain.orderbook/lib/rain.interpreter/src/lib/bitwise/LibCtPop.sol";
import {STACK_TRACER} from "rain.orderbook/lib/rain.interpreter/src/lib/state/LibInterpreterStateNP.sol";

contract TracerLogger is Script {
    fallback() external {
        bytes memory data;
        assembly ("memory-safe") {
            data := mload(0x40)
            mstore(data, calldatasize())
            calldatacopy(add(data, 0x20), 0, calldatasize())
            mstore(0x40, add(data, add(calldatasize(), 0x20)))
        }
        // string memory file = string.concat("./test/csvs/tranche-space-traces.", vm.envString("CSV_FILE_SUFFIX"), ".csv");
        // vm.writeLine(file, string(data));
    }
}

contract XBlockModelling is XBlockStratUtil {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using LibFixedPointDecimalScale for uint256;

    uint256 lastUpdateTimeKey = uint256(keccak256(abi.encodePacked(ORDER_HASH, uint256(1))));
    uint256 trancheSpaceKey = uint256(keccak256(abi.encodePacked(ORDER_HASH, uint256(0))));

    function testChartTrancheSpace(uint256 trancheSpace) external {
        trancheSpace = bound(trancheSpace, 0, 5e18);
        string[] memory ffi = new string[](19);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "src/tranche-strat-refill.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io-test";
        ffi[7] = "--entrypoint";
        ffi[8] = "calculate-io-test";
        ffi[9] = "--bind";
        ffi[10] = string.concat("test-tranche-space-before=", uint2str(trancheSpace));
        ffi[11] = "--bind";
        ffi[12] = "test-base-tranche-size=1000e18";
        ffi[13] = "--bind";
        ffi[14] = "test-now=0";
        ffi[15] = "--bind";
        ffi[16] = "test-last-update-time=0";
        ffi[17] = "--bind";
        ffi[18] = "test-io-ratio-multiplier=1e18";

        bytes memory rainlang = vm.ffi(ffi);

        // console2.log(address(vm));

        address tracerLogger = address(new TracerLogger());
        vm.etch(STACK_TRACER, tracerLogger.code);

        uint256[][] memory context = new uint256[][](0);
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(ORDERBOOK));
        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(rainlang);
        (,,address expression,) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

        (uint256[] memory stack, uint256[] memory kvs) = IInterpreterV2(INTERPRETER).eval2(
            IInterpreterStoreV1(address(STORE)),
            namespace,
            LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint16).max),
            context,
            new uint256[](0)
        );
        (kvs);

        // E.g.
        // ```
        // CSV_FILE_SUFFIX=$(date +%s) forge test -vvv --mt testChartTrancheSpace --offline
        // ```
        string memory file = string.concat("./test/csvs/tranche-space.", vm.envString("CSV_FILE_SUFFIX"), ".csv");

        vm.writeLine(file, string.concat(
            uint2str(trancheSpace),
            ",",
            uint2str(stack[1]),
            ",",
            uint2str(stack[0])
        ));
    }

    function test_trancheModelling() public {
        string memory file = './test/csvs/tranche-space-stack.csv';
        if (vm.exists(file)) vm.removeFile(file);

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(ORDERBOOK));

        vm.writeLine(file, string.concat(
            "Tranche space",
            ",",
            "Amount",
            ",",
            "Price"
        ));

        for (uint256 i = 0; i < 200; i++) {

            uint256 trancheSpace = uint256(1e17*i);
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, trancheSpaceKey), abi.encode(trancheSpace));
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, lastUpdateTimeKey), abi.encode(block.timestamp));

            uint256[] memory stack = eval(
                LibTrancheRefillOrders.getTrancheRefillSellOrder(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
                )
            );

            string memory line = string.concat(
                    uint2str(trancheSpace),
                    ",",
                    uint2str(stack[1]),
                    ",",
                    uint2str(stack[0])
            );

            vm.writeLine(file, line);

            for (uint256 i = 1; i < stack.length; i++) {
                console2.logUint(stack[i]);
            }
        }
    }

    function test_lastUpdateTime() public {
        string memory file = './test/csvs/last-update-time.csv';
        if (vm.exists(file)) vm.removeFile(file);

        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(ORDERBOOK));

        vm.writeLine(file, string.concat(
            "Time (seconds)",
            ",",
            "Amount",
            ",",
            "Price"

        ));

        for (uint256 i = 0; i < (48*8); i++) {
            uint256 time = 30*i;
            vm.warp(time);
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, trancheSpaceKey), abi.encode(uint256(510e16)));
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, lastUpdateTimeKey), abi.encode(uint256(1)));
            uint256[] memory stack = eval(
                LibTrancheRefillOrders.getTrancheRefillSellOrder(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
                )
            );

            string memory line = string.concat(
                    uint2str(time),
                    ",",
                    uint2str(stack[1]),
                    ",",
                    uint2str(stack[0])
            );

            vm.writeLine(file, line);

            for (uint256 i = 1; i < stack.length; i++) {
                console2.logUint(stack[i]);
            }
        }
    }

    function test_trancheAmounts() public {
        string memory file = './test/csvs/tranches.csv';
        FullyQualifiedNamespace namespace =
            LibNamespace.qualifyNamespace(StateNamespace.wrap(uint256(uint160(ORDER_OWNER))), address(ORDERBOOK));
        if (vm.exists(file)) vm.removeFile(file);

        vm.writeLine(file, string.concat(
            "Tranche",
            ",",
            "Tranche Amount",
            ",",
            "Tranche Price"
        ));

        for (uint256 i = 0; i < 200; i++) {

            uint256 trancheSpace = uint256(1e18*i);
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, trancheSpaceKey), abi.encode(trancheSpace));
            vm.mockCall(address(STORE), abi.encodeWithSelector(IInterpreterStoreV1.get.selector, namespace, lastUpdateTimeKey), abi.encode(block.timestamp));
            uint256[] memory stack = eval(
                LibTrancheRefillOrders.getTrancheRefillSellOrder(
                    vm,
                    address(ORDERBOOK_SUPARSER),
                    address(UNISWAP_WORDS)
                )
            );

            string memory line = string.concat(
                    uint2str(trancheSpace / 1e18),
                    ",",
                    uint2str(stack[1]),
                    ",",
                    uint2str(stack[0] * 1e18 / stack[2])
            );

            vm.writeLine(file, line);

            for (uint256 i = 1; i < stack.length; i++) {
                console2.logUint(stack[i]);
            }
        }
    }
}