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

// Tranche Space Constants
uint256 constant TRANCHE_SIZE_BASE_SELL = 3500e18;
uint256 constant TRANCHE_SIZE_BASE_BUY = 17e17; 
uint256 constant TRANCHE_SIZE_GROWTH = 11e17; 

uint256 constant TRANCHE_SPACE_PER_SEC = 11574074e6;
uint256 constant TRANCHE_SPACE_RECHARGE_DELAY = 300;
uint256 constant TRANCHE_SPACE_MIN_DIFF = 1e17;
uint256 constant TRANCHE_SPACE_SNAP_THRESHOLD = 1e16;

uint256 constant IO_RATIO_BASE = 111e16;
uint256 constant IO_RATIO_GROWTH = 102e16;

uint256 constant TWAP_DURATION = 1800;
uint256 constant TWAP_FEE = 500;


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
        string[] memory ffi = new string[](43);
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
        ffi[10] = string.concat("tranche-space-per-second=",uint2str(TRANCHE_SPACE_PER_SEC));
        ffi[11] = "--bind";
        ffi[12] = string.concat("tranche-space-recharge-delay=",uint2str(TRANCHE_SPACE_RECHARGE_DELAY));
        ffi[13] = "--bind";
        ffi[14] = string.concat("tranche-size-base=",uint2str(TRANCHE_SIZE_BASE_BUY));
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-growth=",uint2str(TRANCHE_SIZE_GROWTH));
        ffi[17] = "--bind";
        ffi[18] = string.concat("io-ratio-base=",uint2str(IO_RATIO_BASE));
        ffi[19] = "--bind";
        ffi[20] = string.concat("io-ratio-growth=",uint2str(IO_RATIO_GROWTH));
        ffi[21] = "--bind";
        ffi[22] = "reference-stable=0x6B175474E89094C44Da98b954EedeAC495271d0F";
        ffi[23] = "--bind";
        ffi[24] = "reference-stable-decimals=18";
        ffi[25] = "--bind";
        ffi[26] = "reference-reserve=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        ffi[27] = "--bind";
        ffi[28] = "reference-reserve-decimals=18";
        ffi[29] = "--bind";
        ffi[30] = string.concat("twap-duration=",uint2str(TWAP_DURATION));
        ffi[31] = "--bind";
        ffi[32] = string.concat("twap-fee=",uint2str(TWAP_FEE));
        ffi[33] = "--bind";
        ffi[34] = string.concat("min-tranche-space-diff=",uint2str(TRANCHE_SPACE_MIN_DIFF));
        ffi[35] = "--bind";
        ffi[36] = string.concat("tranche-space-snap-threshold=",uint2str(TRANCHE_SPACE_SNAP_THRESHOLD));
        ffi[37] = "--bind";
        ffi[38] = "get-last-tranche='get-real-last-tranche";
        ffi[39] = "--bind";
        ffi[40] = "set-last-tranche='set-real-last-tranche";
        ffi[41] = "--bind";
        ffi[42] = "io-ratio-multiplier='io-ratio-multiplier-buy"; 
        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }
    function getTrancheRefillSellOrder(Vm vm, address orderBookSubparser, address uniswapWords) internal returns (bytes memory trancheRefill) {
        string[] memory ffi = new string[](43);
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
        ffi[10] = string.concat("tranche-space-per-second=",uint2str(TRANCHE_SPACE_PER_SEC));
        ffi[11] = "--bind";
        ffi[12] = string.concat("tranche-space-recharge-delay=",uint2str(TRANCHE_SPACE_RECHARGE_DELAY));
        ffi[13] = "--bind";
        ffi[14] = string.concat("tranche-size-base=",uint2str(TRANCHE_SIZE_BASE_SELL));
        ffi[15] = "--bind";
        ffi[16] = string.concat("tranche-size-growth=",uint2str(TRANCHE_SIZE_GROWTH));
        ffi[17] = "--bind";
        ffi[18] = string.concat("io-ratio-base=",uint2str(IO_RATIO_BASE));
        ffi[19] = "--bind";
        ffi[20] = string.concat("io-ratio-growth=",uint2str(IO_RATIO_GROWTH));
        ffi[21] = "--bind";
        ffi[22] = "reference-stable=0x6B175474E89094C44Da98b954EedeAC495271d0F";
        ffi[23] = "--bind";
        ffi[24] = "reference-stable-decimals=18";
        ffi[25] = "--bind";
        ffi[26] = "reference-reserve=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        ffi[27] = "--bind";
        ffi[28] = "reference-reserve-decimals=18";
        ffi[29] = "--bind";
        ffi[30] = string.concat("twap-duration=",uint2str(TWAP_DURATION));
        ffi[31] = "--bind";
        ffi[32] = string.concat("twap-fee=",uint2str(TWAP_FEE));
        ffi[33] = "--bind";
        ffi[34] = string.concat("min-tranche-space-diff=",uint2str(TRANCHE_SPACE_MIN_DIFF));
        ffi[35] = "--bind";
        ffi[36] = string.concat("tranche-space-snap-threshold=",uint2str(TRANCHE_SPACE_SNAP_THRESHOLD));
        ffi[37] = "--bind";
        ffi[38] = "get-last-tranche='get-real-last-tranche";
        ffi[39] = "--bind";
        ffi[40] = "set-last-tranche='set-real-last-tranche";
        ffi[41] = "--bind";
        ffi[42] = "io-ratio-multiplier='io-ratio-multiplier-sell";

        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getTestCalculateTrancheSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapWords,
        uint256 trancheBaseSize,
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
        ffi[8] = string.concat("tranche-space-per-second=",uint2str(TRANCHE_SPACE_PER_SEC));
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-recharge-delay=",uint2str(TRANCHE_SPACE_RECHARGE_DELAY));
        ffi[11] = "--bind";
        ffi[12] = string.concat("test-tranche-space-before=",uint2str(testTrancheSpaceBefore));
        ffi[13] = "--bind";
        ffi[14] = string.concat("test-last-update-time=",uint2str(testLastUpdateTime));
        ffi[15] = "--bind";
        ffi[16] = string.concat("test-now=",uint2str(testNow));
        ffi[17] = "--bind";
        ffi[18] = string.concat("tranche-size-base=",uint2str(trancheBaseSize));
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-size-growth=",uint2str(TRANCHE_SIZE_GROWTH));
        ffi[21] = "--bind";
        ffi[22] = "get-last-tranche='get-test-last-tranche";
        return bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getTestHandleIoSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapWords,
        uint256 trancheBaseSize,
        uint256 testTrancheSpaceBefore,
        uint256 testLastUpdateTime,
        uint256 testNow
    ) internal returns (bytes memory) {
        string[] memory ffi = new string[](29);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "handle-io";
        ffi[7] = "--bind";
        ffi[8] = string.concat("tranche-space-per-second=",uint2str(TRANCHE_SPACE_PER_SEC));
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-recharge-delay=",uint2str(TRANCHE_SPACE_RECHARGE_DELAY));
        ffi[11] = "--bind";
        ffi[12] = string.concat("test-tranche-space-before=",uint2str(testTrancheSpaceBefore));
        ffi[13] = "--bind";
        ffi[14] = string.concat("test-last-update-time=",uint2str(testLastUpdateTime));
        ffi[15] = "--bind";
        ffi[16] = string.concat("test-now=",uint2str(testNow));
        ffi[17] = "--bind";
        ffi[18] = string.concat("tranche-size-base=",uint2str(trancheBaseSize));
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-size-growth=",uint2str(TRANCHE_SIZE_GROWTH));
        ffi[21] = "--bind";
        ffi[22] = string.concat("tranche-space-snap-threshold=",uint2str(TRANCHE_SPACE_SNAP_THRESHOLD));
        ffi[23] = "--bind";
        ffi[24] = string.concat("min-tranche-space-diff=",uint2str(TRANCHE_SPACE_MIN_DIFF));
        ffi[25] = "--bind";
        ffi[26] = "get-last-tranche='get-test-last-tranche";
        ffi[27] = "--bind";
        ffi[28] = "set-last-tranche='set-test-last-tranche";
        return bytes.concat(getSubparserPrelude(orderBookSubparser,uniswapWords), vm.ffi(ffi));
    }

    function getTestCalculateIoSource(
        Vm vm,
        address orderBookSubparser,
        address uniswapWords,
        uint256 trancheBaseSize,
        uint256 testTrancheSpaceBefore,
        uint256 testLastUpdateTime,
        uint256 testNow
    ) internal returns (bytes memory) {

        string[] memory ffi = new string[](45);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-space.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--bind";
        ffi[8] = string.concat("tranche-space-per-second=",uint2str(TRANCHE_SPACE_PER_SEC));
        ffi[9] = "--bind";
        ffi[10] = string.concat("tranche-space-recharge-delay=",uint2str(TRANCHE_SPACE_RECHARGE_DELAY));
        ffi[11] = "--bind";
        ffi[12] = string.concat("test-tranche-space-before=",uint2str(testTrancheSpaceBefore));
        ffi[13] = "--bind";
        ffi[14] = string.concat("test-last-update-time=",uint2str(testLastUpdateTime));
        ffi[15] = "--bind";
        ffi[16] = string.concat("test-now=",uint2str(testNow));
        ffi[17] = "--bind";
        ffi[18] = string.concat("tranche-size-base=",uint2str(trancheBaseSize));
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-size-growth=",uint2str(TRANCHE_SIZE_GROWTH));
        ffi[21] = "--bind";
        ffi[22] = string.concat("tranche-space-snap-threshold=",uint2str(TRANCHE_SPACE_SNAP_THRESHOLD));
        ffi[23] = "--bind";
        ffi[24] = string.concat("min-tranche-space-diff=",uint2str(TRANCHE_SPACE_MIN_DIFF));
        ffi[25] = "--bind";
        ffi[26] = "get-last-tranche='get-test-last-tranche";
        ffi[27] = "--bind";
        ffi[28] = string.concat("io-ratio-base=",uint2str(IO_RATIO_BASE));
        ffi[29] = "--bind";
        ffi[30] = string.concat("io-ratio-growth=",uint2str(IO_RATIO_GROWTH));
        ffi[31] = "--bind";
        ffi[32] = "io-ratio-multiplier='io-ratio-multiplier-sell";
        ffi[33] = "--bind";
        ffi[34] = "reference-stable=0x6B175474E89094C44Da98b954EedeAC495271d0F";
        ffi[35] = "--bind";
        ffi[36] = "reference-stable-decimals=18";
        ffi[37] = "--bind";
        ffi[38] = "reference-reserve=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
        ffi[39] = "--bind";
        ffi[40] = "reference-reserve-decimals=18";
        ffi[41] = "--bind";
        ffi[42] = string.concat("twap-duration=",uint2str(TWAP_DURATION));
        ffi[43] = "--bind";
        ffi[44] = string.concat("twap-fee=",uint2str(TWAP_FEE));
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
