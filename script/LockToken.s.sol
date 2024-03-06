// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";
import {LOCK_TOKEN, IHoudiniSwapToken} from "src/XBlockStratTrancheRefill.sol";

// WhiteList Contract Address
//
// source .env && forge script script/LockToken.s.sol:LockAMMPair --sig "run(address, bool)" --rpc-url $RPC_URL_ETH {contractAddress} {boolValue} --broadcast
//
contract LockAMMPair is Script {
    function run(address contractAddress, bool value) external {
        // Signer Address needs to be the owner of the LOCK contract.
        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));

        IHoudiniSwapToken(address(LOCK_TOKEN)).setAutomatedMarketMakerPair(contractAddress, value);

        vm.stopBroadcast();
    }
}

// WhiteList Account Address
//
// source .env && forge script script/LockToken.s.sol:LockExcludeFromList --sig "run(address, bool)" --rpc-url $RPC_URL_ETH {contractAddress} {boolValue} --broadcast
//
contract LockExcludeFromList is Script {
    function run(address account, bool value) external {
        // Signer Address needs to be the owner of the LOCK contract.
        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));

        address[] memory accounts = new address[](1);
        accounts[0] = account;

        IHoudiniSwapToken(address(LOCK_TOKEN)).excludeFromLimits(accounts, value);

        vm.stopBroadcast();
    }
}
