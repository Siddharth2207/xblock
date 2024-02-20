// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {console2, Test} from "forge-std/Test.sol";
import { POOL, LOCK_TOKEN, WETH_TOKEN, LOCK_OWNER } from "src/XBlockStratTrancheRefill.sol";
import { LibDeploy } from "rain.uniswap/src/lib/v3/LibDeploy.sol";

interface IQuoter {

    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        view
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

}

interface IHoudiniSwapToken { 
    function launch() external;
    function setAutomatedMarketMakerPair(address account,bool value) external;
}

contract UniswapV3Modelling is Test {
    IQuoter quoter;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("RPC_URL_ETH"));
        vm.selectFork(fork);
        quoter = IQuoter(LibDeploy.newQuoter(vm));
    }

    function test_exportPrices() public {
        string memory file = './test/csvs/pool-modelling.csv';
        if (vm.exists(file)) vm.removeFile(file);

        vm.writeLine(file, "LOCK/ETH price");

        quoter = IQuoter(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);

        uint256 ethusd = 434631089935807;
        uint256 usdeth = 2301e18;

        // this will keep increasing the quote amount by resolution and export the prices
        for (uint256 i = 0; i < 1000; i++) {
            uint256 resolution = 1000;
            uint256 baseAmount = ethusd * 850000; // at this point LOCK will be worth $1.10
            uint256 amountIn = ethusd * resolution * i + baseAmount;
            (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate) = quoter.quoteExactInputSingle(
                IQuoter.QuoteExactInputSingleParams(
                    address(WETH_TOKEN),
                    address(LOCK_TOKEN),
                    amountIn,
                    uint24(10000),
                    0
                )
            );

            vm.writeLine(file, string.concat(
                uint2str(price(sqrtPriceX96After)*usdeth/1e18)
            ));
        }
    }

    function launchLockToken() public { 
        vm.startPrank(LOCK_OWNER);
        IHoudiniSwapToken(address(LOCK_TOKEN)).launch();
        // IHoudiniSwapToken(address(LOCK_TOKEN)).setAutomatedMarketMakerPair(POOL,true);
        vm.stopPrank();
    }

    function price(uint256 sqrtPriceX96) public pure returns (uint256) {
        return ((sqrtPriceX96 * 1e18) / (2**96))**2/1e18;
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
}