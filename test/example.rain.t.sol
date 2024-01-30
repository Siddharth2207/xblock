// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {XBlockStratUtil, IInterpreterV2, IInterpreterStoreV2} from "test/util/XBlockStratUtils.sol";
import {IInterpreterStoreV1} from "rain.orderbook/lib/rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {LibEncodedDispatch, SourceIndexV2} from "rain.orderbook/lib/rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {FullyQualifiedNamespace} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IInterpreterV2.sol";

contract ExampleRainTest is XBlockStratUtil {
    function testExampleRain() external {
        string[] memory inputs = new string[](9);
        inputs[0] = "rain";
        inputs[1] = "dotrain";
        inputs[2] = "compose";
        inputs[3] = "-i";
        inputs[4] = "./src/example.rain";
        inputs[5] = "--entrypoints";
        inputs[6] = "calculate-io";
        inputs[7] = "--entrypoints";
        inputs[8] = "handle-io";

        bytes memory rainlang = vm.ffi(inputs);
        console2.log(string(rainlang));

        (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(rainlang);

        console2.logBytes(bytecode);
        for (uint256 i = 0; i < constants.length; i++) {
            console2.log("constant", i, constants[i]);
        }

        (IInterpreterV2 interpreter, IInterpreterStoreV1 store, address expression, bytes memory io) = EXPRESSION_DEPLOYER.deployExpression2(bytecode, constants);

        (uint256[] memory stack, uint256[] memory writes) = interpreter.eval2(
            store,
            FullyQualifiedNamespace.wrap(0),
            LibEncodedDispatch.encode2(expression, SourceIndexV2.wrap(0), type(uint256).max),
            new uint256[][](0),
            new uint256[](0)
        );

        console2.log("stack length", stack.length);
        for (uint256 i = 0; i < stack.length; i++) {
            console2.log("stack", i, stack[i]);
        }
    }
}