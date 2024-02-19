// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {IRouteProcessor} from "src/interface/IRouteProcessor.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IOrderBookV3,
    IO,
    OrderV2,
    IO,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "rain.orderbook/src/interface/unstable/IOrderBookV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @dev https://etherscan.io/address/0x922D8563631B03C2c4cf817f4d18f6883AbA0109
IERC20 constant LOCK_TOKEN = IERC20(0x922D8563631B03C2c4cf817f4d18f6883AbA0109);

/// @dev https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
IERC20 constant WETH_TOKEN = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

address constant LOCK_TOKEN_HOLDER = address(0xa9A67f2748e31E2BBAB1034F067b52fa9dE27b0e);

address constant WETH_TOKEN_HOLDER = address(0x8EB8a3b98659Cce290402893d0123abb75E3ab28);

address constant LOCK_OWNER = address(0xE23B2ecD2B71133086B8e15b78a4a174ea491653);

address constant APPROVED_EOA = address(0x19f95a84aa1C48A2c6a7B2d5de164331c86D030C);

address constant POOL = address(0x7D45a2557bECd766A285d07a4701f5c64D716e2f);

address constant DAI_TOKEN_HOLDER = address(0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8);

IERC20 constant DAI_TOKEN = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

/// @dev https://etherscan.io/address/0x827179dD56d07A7eeA32e3873493835da2866976
IRouteProcessor constant ROUTE_PROCESSOR = IRouteProcessor(address(0x827179dD56d07A7eeA32e3873493835da2866976));

uint256 constant VAULT_ID = uint256(keccak256("vault"));

interface IHoudiniSwapToken {
    function launch() external;
    function setAutomatedMarketMakerPair(address account, bool value) external;
    function excludeFromLimits(
        address[] calldata accounts,
        bool value
    ) external;
}

function uint2str(uint _i) pure returns (string memory _uintAsString) {
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

library LibTrancheRefillOrders {

    using Strings for address;

    function getTrancheRefillBuyOrder(Vm vm, address orderBookSubparser, address uniswapWords) internal returns (bytes memory trancheRefill) {
        string[] memory ffi = new string[](41);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "tranche-space-per-second=1157407400000000000000";
        ffi[11] = "--bind";
        ffi[12] = "tranche-space-recharge-delay=300";
        ffi[13] = "--bind";
        ffi[14] = "tranche-size-base=3500000000000000000000";
        ffi[15] = "--bind";
        ffi[16] = "tranche-size-growth=1100000000000000000";
        ffi[17] = "--bind";
        ffi[18] = "io-ratio-base=1110000000000000000";
        ffi[19] = "--bind";
        ffi[20] = "io-ratio-growth=1020000000000000000";
        ffi[21] = "--bind";
        ffi[22] = "reference-stable=0x6B175474E89094C44Da98b954EedeAC495271d0F";
        ffi[23] = "--bind";
        ffi[24] = "reference-stable-decimals=18";
        ffi[25] = "--bind";
        ffi[26] = "reference-reserve=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        ffi[27] = "--bind";
        ffi[28] = "reference-reserve-decimals=18";
        ffi[29] = "--bind";
        ffi[30] = "twap-duration=1800";
        ffi[31] = "--bind";
        ffi[32] = "min-tranche-space-diff=100000000000000000";
        ffi[33] = "--bind";
        ffi[34] = "tranche-space-snap-threshold=10000000000000000"; 
        ffi[35] = "--bind";
        ffi[36] = "get-last-tranche='get-real-last-tranche";
        ffi[37] = "--bind";
        ffi[38] = "set-last-tranche='set-real-last-tranche";
        ffi[39] = "--bind";
        ffi[40] = "io-ratio-multiplier='io-ratio-multiplier-buy"; 

        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getTrancheRefillSellOrder(Vm vm, address orderBookSubparser, address uniswapWords) internal returns (bytes memory trancheRefill) {
        string[] memory ffi = new string[](41);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "tranche-space-per-second=1157407400000000000000";
        ffi[11] = "--bind";
        ffi[12] = "tranche-space-recharge-delay=300";
        ffi[13] = "--bind";
        ffi[14] = "tranche-size-base=3500000000000000000000";
        ffi[15] = "--bind";
        ffi[16] = "tranche-size-growth=1100000000000000000";
        ffi[17] = "--bind";
        ffi[18] = "io-ratio-base=1110000000000000000";
        ffi[19] = "--bind";
        ffi[20] = "io-ratio-growth=1020000000000000000";
        ffi[21] = "--bind";
        ffi[22] = "reference-stable=0x6B175474E89094C44Da98b954EedeAC495271d0F";
        ffi[23] = "--bind";
        ffi[24] = "reference-stable-decimals=18";
        ffi[25] = "--bind";
        ffi[26] = "reference-reserve=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        ffi[27] = "--bind";
        ffi[28] = "reference-reserve-decimals=18";
        ffi[29] = "--bind";
        ffi[30] = "twap-duration=1800";
        ffi[31] = "--bind";
        ffi[32] = "min-tranche-space-diff=100000000000000000";
        ffi[33] = "--bind";
        ffi[34] = "tranche-space-snap-threshold=10000000000000000"; 
        ffi[35] = "--bind";
        ffi[36] = "get-last-tranche='get-real-last-tranche";
        ffi[37] = "--bind";
        ffi[38] = "set-last-tranche='set-real-last-tranche";
        ffi[39] = "--bind";
        ffi[40] = "io-ratio-multiplier='io-ratio-multiplier-sell";

        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getTestCalculateTrancheSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapWords,
        uint256 testTrancheSpaceBefore,
        uint256 testLastUpdateTime,
        uint256 testNow
    ) internal returns (bytes memory) {
        string[] memory ffi = new string[](23);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-tranche";
        ffi[7] = "--bind";
        ffi[8] = "tranche-space-per-second=115740740000000";
        ffi[9] = "--bind";
        ffi[10] = "tranche-space-recharge-delay=300";
        ffi[11] = "--bind";
        ffi[12] = string.concat("test-tranche-space-before=",uint2str(testTrancheSpaceBefore));
        ffi[13] = "--bind";
        ffi[14] = string.concat("test-last-update-time=",uint2str(testLastUpdateTime));
        ffi[15] = "--bind";
        ffi[16] = string.concat("test-now=",uint2str(testNow));
        ffi[17] = "--bind";
        ffi[18] = "tranche-size-base=3500000000000000000000";
        ffi[19] = "--bind";
        ffi[20] = "tranche-size-growth=1100000000000000000";
        ffi[21] = "--bind";
        ffi[22] = "get-last-tranche='get-test-last-tranche";

        return bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser, address uniswapWords) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER = bytes(
            string.concat(
                "using-words-from ", obSubparser.toHexString(), " ", uniswapWords.toHexString(), " "
            )
        );
        return RAINSTRING_OB_SUBPARSER;
    }

}
