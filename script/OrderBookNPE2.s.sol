// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "script/util/OrderBookNPE2DeployUtil.sol";

// Add Buy and Sell TrendRefill Strat Order to Orderbook.
//
// source .env && forge script script/OrderBookNPE2.s.sol:AddTrendRefillStratOrder --sig "run(address, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {vaultId} --broadcast
//
contract AddTrendRefillStratOrder is OrderBookNPE2DeployUtil {
    IOrderBookV3 orderbook;

    function run(address orderBookAddress, uint256 vaultId) external {
        orderbook = IOrderBookV3(orderBookAddress);

        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));
        (OrderConfigV2 memory buyOrder, OrderConfigV2 memory sellOrder) = getBuySellOrders(vaultId);
        orderbook.addOrder(buyOrder);
        orderbook.addOrder(sellOrder);
        vm.stopBroadcast();
    }
}

// Deposit a token to Orderbook.
//
// source .env && forge script script/OrderBookNPE2.s.sol:Deposit --sig "run(address, address, uint256, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {token} {vaultId} {amount} --broadcast
//
contract Deposit is OrderBookNPE2DeployUtil {
    IOrderBookV3 orderbook;

    function run(address orderBookAddress, address token, uint256 vaultId, uint256 amount) external {
        orderbook = IOrderBookV3(orderBookAddress);

        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));
        approveTokensForDeposit(address(orderbook), token, amount);
        orderbook.deposit(token, vaultId, amount);
        vm.stopBroadcast();
    }
}

// Withdraw tokens from Orderbook.
//
// source .env && forge script script/OrderBookNPE2.s.sol:Withdraw --sig "run(address, address, uint256, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {token} {vaultId} {amount} --broadcast
//
contract Withdraw is OrderBookNPE2DeployUtil {
    IOrderBookV3 orderbook;

    function run(address orderBookAddress, address token, uint256 vaultId, uint256 amount) external {
        orderbook = IOrderBookV3(orderBookAddress);

        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));
        orderbook.withdraw(token, vaultId, amount);
        vm.stopBroadcast();
    }
}

// Remove an order from Orderbook
//
// source .env && forge script script/OrderBookNPE2.s.sol:RemoveOrder --sig "run(address, string memory)()" --rpc-url $RPC_URL_ETH {orderBookAddress} {txHash} --broadcast
//
contract RemoveOrder is OrderBookNPE2DeployUtil {
    IOrderBookV3 orderbook;

    function run(address orderBookAddress, string memory txHash) external {
        orderbook = IOrderBookV3(orderBookAddress);

        string memory rpcUrl = vm.envString("RPC_URL_ETH");
        string memory castCommand = string.concat("cast receipt ", txHash, " -j --rpc-url ", rpcUrl);

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = castCommand;
        bytes memory resultReceipt = vm.ffi(inputs);

        uint256 i = 0;
        bytes memory addOrderEventData;

        // Check all the logs[i].topics[0] == "0x6fa57e1a7a1fbbf3623af2b2025fcd9a5e7e4e31a2a6ec7523445f18e9c50ebf"
        // and retireve the logs[i].data when matched
        while (true) {
            string memory topic = string.concat(".logs[", Strings.toString(i), "].topics[0]");
            bytes memory parsedTopic = stdJson.parseRaw(string(resultReceipt), topic);

            //Checking for the "AddOrder" event topic
            bytes memory expectedTopic = hex"6fa57e1a7a1fbbf3623af2b2025fcd9a5e7e4e31a2a6ec7523445f18e9c50ebf";
            if (Strings.equal(string(parsedTopic), string(expectedTopic))) {
                addOrderEventData =
                    stdJson.parseRaw(string(resultReceipt), string.concat(".logs[", Strings.toString(i), "].data"));
                break;
            }
            i++;
        }

        // Decode the addOrderEventData into the OrderV2 struct
        (,, OrderV2 memory order,) =
            abi.decode(abi.decode(addOrderEventData, (bytes)), (address, IExpressionDeployerV3, OrderV2, bytes32));

        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));
        orderbook.removeOrder(order);
        vm.stopBroadcast();
    }
}
