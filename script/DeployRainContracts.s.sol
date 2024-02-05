// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";
import "src/abstract/RainContracts.sol";

contract DeployRainContracts is RainContracts, Script {

    /// @dev https://etherscan.io/address/0x27C062142b9DF4D07191bd2127Def504DC9e9937
    address constant ETH_CLONE_FACTORY = 0x27C062142b9DF4D07191bd2127Def504DC9e9937;
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYMENT_KEY"));

        // Deploy All Contracts
        deployContracts(vm,ETH_CLONE_FACTORY);

        vm.stopBroadcast();
    }
}