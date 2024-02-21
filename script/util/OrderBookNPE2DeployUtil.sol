// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";
import {IExpressionDeployerV3, IParserV1, IOrderBookV3, EvaluableConfigV3} from "src/abstract/RainContracts.sol";
import {
    LOCK_TOKEN,
    WETH_TOKEN,
    SafeERC20,
    IERC20,
    OrderConfigV2,
    OrderV2,
    IO,
    LibTrancheRefillOrders
} from "src/XBlockStratTrancheRefill.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract OrderBookNPE2DeployUtil is Script {
    using SafeERC20 for IERC20;
    using stdJson for string;

    function approveTokensForDeposit(address orderbook, address token, uint256 amount) public {
        IERC20(token).safeApprove(orderbook, amount);
    }

    function getBuySellOrders(uint256 vaultId)
        public
        returns (OrderConfigV2 memory buyOrder, OrderConfigV2 memory sellOrder)
    {
        IParserV1 PARSER = IParserV1(vm.envAddress("PARSER"));
        IExpressionDeployerV3 EXPRESSION_DEPLOYER = IExpressionDeployerV3(vm.envAddress("EXPRESSION_DEPLOYER"));
        address ORDERBOOK_SUPARSER = vm.envAddress("ORDERBOOK_SUBPARSER");
        address UNISWAP_WORDS = vm.envAddress("UNISWAP_WORDS");

        IO[] memory inputs = new IO[](1);
        inputs[0] = IO(address(LOCK_TOKEN), 18, vaultId);

        IO[] memory outputs = new IO[](1);
        outputs[0] = IO(address(WETH_TOKEN), 18, vaultId);
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrancheRefillOrders.getTrancheRefillBuyOrder(vm, address(ORDERBOOK_SUPARSER), address(UNISWAP_WORDS))
            );
            EvaluableConfigV3 memory evaluableConfig = EvaluableConfigV3(EXPRESSION_DEPLOYER, bytecode, constants);
            buyOrder = OrderConfigV2(inputs, outputs, evaluableConfig, "");
        }
        {
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(
                LibTrancheRefillOrders.getTrancheRefillSellOrder(
                    vm, address(ORDERBOOK_SUPARSER), address(UNISWAP_WORDS)
                )
            );
            EvaluableConfigV3 memory evaluableConfig = EvaluableConfigV3(EXPRESSION_DEPLOYER, bytecode, constants);
            sellOrder = OrderConfigV2(outputs, inputs, evaluableConfig, "");
        }
    }
}
