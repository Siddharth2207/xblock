// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {IRouteProcessor} from "src/interface/IRouteProcessor.sol";

/// @dev https://etherscan.io/address/0x827179dD56d07A7eeA32e3873493835da2866976
IRouteProcessor constant ROUTE_PROCESSOR = IRouteProcessor(address(0x827179dD56d07A7eeA32e3873493835da2866976));

uint256 constant VAULT_ID = uint256(keccak256("vault"));

/// @dev Shared seed so that sells and buys have the same view of the rng.
/// `$ openssl rand -hex 32`
uint256 constant SEED = 0x844298f03374ebab272d6aea77dd06a67ca29d81adbe996adfd748ae279abd97;

/// @dev Initial tracker for calculating up down ratio.
uint256 constant TRACKER = 0x5555555555555555555555555555555555555555555555555555555555555555;

/// @dev average cooldown.
uint256 constant TARGET_COOLDOWN_18 = 1440e18;
/// @dev $166.66 recurring
uint256 constant TARGET_USDT_18 = 166e18 + 666666666666666666;
/// @dev $0.08 bounty
uint256 constant BOUNTY = 8e16;
/// @dev 1e18 constant amount
uint256 constant CONSTANT_USDT_QUOTE = 1e18;

// Use words under OrderBookSubParser
bytes constant RAINSTRING_OB_SUBPARSER_PRELUDE = "using-words-from 0x754aD38Bcf5198E1a19a45687D2FefDD14716fa9";

bytes constant RAINSTRING_JITTERY_BINOMIAL =
// Paramaterise the seed for our randomness (hash).
    "input:,"
    // The binomial part is using ctpop over a hash to simulate 10 coin flips.
    // produces a decimal number between 0 and 10.
    "binomial18-10: decimal18-scale18<0>(bitwise-count-ones(bitwise-decode<0 10>(hash(input)))),"
    // The noise is a decimal number between 0 and 1.
    "noise18-1: int-mod(hash(input 0) 1e18),"
    // The jittery is the binomial plus the noise. Which is a range 0-11.
    "jittery-11: decimal18-add(binomial18-10 noise18-1),"
    // The final jittery is the jittery divided by 11, which is a range 0-1.
    "jittery-1: decimal18-div(jittery-11 11e18);";

bytes constant RAINSTRING_PRELUDE =
// Sushi v2 factory address.
    "polygon-sushi-v2-factory: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4,"
    // TRADE token address.
    "trade-token-address: 0x692AC1e363ae34b6B489148152b12e2785a3d8d6,"
    // USDT token address.
    "usdt-token-address: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,"
    // The last time is stored under the order hash, as there's only a single
    // value stored for this order.
    "last-time: get(order-hash()),"
    // Set the last time to this block.
    ":set(order-hash() block-timestamp()),"
    // Ensure jittered cooldown.
    ":call<3 0>(last-time 1440e18),"
    // Get jittered usdt amounts.
    "jittered-amount-usdt18 jittered-amount-usdt6: call<4 2>(last-time 166666666666666666666),"
    // Get TRADE amount for constant USDT amount
    "constant-trade-quote: uniswap-v2-quote(polygon-sushi-v2-factory 1e18 usdt-token-address trade-token-address),"
    // ud-ratio, du-ratio for the constant trade amount.
    "ups downs: call<5 2>(0x844298f03374ebab272d6aea77dd06a67ca29d81adbe996adfd748ae279abd97 constant-trade-quote),";

bytes constant RAINSTRING_ENSURE_COOLDOWN =
// Inputs.
    "last-time target-cooldown18:,"
    // Multiplier [0, 1] from internal call.
    "cooldown-random-multiplier18: call<2 1>(hash(last-time)),"
    // Actual cooldown as 18 decimals.
    "cooldown18: decimal18-mul(decimal18-mul(target-cooldown18 2e18) cooldown-random-multiplier18),"
    // Integer cooldown.
    "cooldown: decimal18-scale-n<0>(cooldown18),"
    // Error if cooldown in the future.
    ":ensure<1>(less-than(int-add(last-time cooldown) block-timestamp()));";

bytes constant RAINSTRING_TARGET_USDT =
// Inputs.
    "last-time target-usdt18:,"
    // Multiplier [0, 1] from internal call.
    "amount-random-multiplier18: call<2 1>(last-time),"
    // Actual amount as 18 decimals.
    "amount-usdt18: decimal18-mul(decimal18-mul(target-usdt18 2e18) amount-random-multiplier18),"
    // Uniswap needs the usdt amount as 6 decimals (tether's native size).
    "amount-usdt6: decimal18-scale-n<6>(amount-usdt18);";

bytes constant RAINSTRING_UD_RATIO =
// Inputs.
    "seed current-value:,"
    // Alternating 1s and 0s as initial tracker state.
    "initial-tracker: 0x5555555555555555555555555555555555555555555555555555555555555555,"
    // Build a last value key from the seed.
    "last-value-key: hash(seed),"
    // Build a tracker key from the last value key.
    "tracker-key: hash(last-value-key),"
    // Get the last value.
    "last-value: get(last-value-key),"
    // Tracker just shifts 1 bit to the left, which drops the oldest value, and
    // then ORs the new value in, which is 1 if the current value is greater
    // than the last value, and 0 otherwise.
    "tracker: bitwise-or(bitwise-shift-left<1>(any(get(tracker-key) initial-tracker)) greater-than(current-value last-value)),"
    // ups is the number of 1 bits in the 10 bit tracker.
    "ups: bitwise-count-ones(bitwise-decode<0 10>(tracker)),"
    // downs is the number of 0 bits in the 10 bit tracker.
    "downs: int-sub(10 ups),"
    // Set the last value.
    ":set(last-value-key current-value),"
    // Set the tracker.
    ":set(tracker-key tracker);";

bytes constant RAINSTRING_CALCULATE_ORDER_SELL =
// du-ratio for the constant amount
    "du-ratio: decimal18-div(decimal18-scale18<0>(int-add(1 downs)) decimal18-scale18<0>(int-add(1 ups))),"
    // If the equivalent trade amount is going UP that means the price is going
    // DOWN. Therefore we want to sell LESS, and vice versa, so we multiple by the
    // du ratio.
    "amount-usdt18: decimal18-mul(jittered-amount-usdt18 decimal18-power(du-ratio 7e17)),"
    // Sushi needs the usdt amount as 6 decimals (tether's native size).
    "amount-usdt6: decimal18-scale-n<6>(amount-usdt18),"
    // Token in for uniswap is ob's token out, and vice versa.
    // We want the timestamp as well as the `trade` amount that sushi wants in.
    // TRADE is already 18 decimals, so we don't need to scale it.
    "last-price-timestamp trade-amount18: uniswap-v2-amount-in<1>(polygon-sushi-v2-factory amount-usdt6 trade-token-address usdt-token-address),"
    // Don't allow the price to change this block before this trade.
    ":ensure<6>(less-than(last-price-timestamp block-timestamp())),"
    // Order output max is the trade amount from sushi.
    "order-output-max18: trade-amount18,"
    // IO ratio is the usdt target divided by the trade amount from sushi.
    // 8e16 is subtracted from the target to give a small bounty to the clearer
    // to cover gas. This was empirically measured to clear about 90% of trades.
    "io-ratio: decimal18-div(decimal18-sub(amount-usdt18 8e16) order-output-max18)"
    // end calculate order
    ";";

bytes constant RAINSTRING_HANDLE_IO_SELL =
// context 4 4 aliased by output-vault-balance-decrease() is the vault outputs as absolute values.
// context 2 0 aliased by calculated-max-output() is the calculated output as decimal 18.
// TRADE is the output which is decimal 18 natively so no scaling is needed.
 ":ensure<5>(greater-than-or-equal-to(output-vault-balance-decrease() calculated-max-output()));";

function rainstringSell() pure returns (bytes memory) {
    return bytes.concat(
        RAINSTRING_OB_SUBPARSER_PRELUDE,
        RAINSTRING_PRELUDE,
        RAINSTRING_CALCULATE_ORDER_SELL,
        RAINSTRING_HANDLE_IO_SELL,
        RAINSTRING_JITTERY_BINOMIAL,
        RAINSTRING_ENSURE_COOLDOWN,
        RAINSTRING_TARGET_USDT,
        RAINSTRING_UD_RATIO
    );
}

bytes constant RAINSTRING_CALCULATE_ORDER_BUY =
// ud-ratio for the constant amount
    "ud-ratio: decimal18-div(decimal18-scale18<0>(int-add(1 ups)) decimal18-scale18<0>(int-add(1 downs))),"
    // If the equivalent trade amount is going UP that means the price is going
    // DOWN. Therefore we want to buy MORE, and vice versa, so we multiply by the
    // ud ratio.
    "amount-usdt18: decimal18-mul(jittered-amount-usdt18 ud-ratio),"
    // Sushi needs the usdt amount as 6 decimals (tether's native size).
    "amount-usdt6: decimal18-scale-n<6>(amount-usdt18),"
    // Token out for uni is in for ob, and vice versa.
    // We want the timestamp as well as the trade amount that sushi will give us.
    // TRADE is already 18 decimals, so we don't need to scale it.
    "last-price-timestamp trade-amount18: uniswap-v2-amount-out<1>(polygon-sushi-v2-factory amount-usdt6 usdt-token-address trade-token-address),"
    // Don't allow the price to change this block before this trade.
    ":ensure<6>(less-than(last-price-timestamp block-timestamp())),"
    // Order output max is the usdt amount as decimal 18.
    // Adding a 8e16 bounty to the target to cover gas. This was empirically
    // measured to clear about 90% of trades.
    "order-output-max18: decimal18-add(amount-usdt18 8e16),"
    // IO ratio is the trade amount from sushi divided by the usdt target.
    "io-ratio: decimal18-div(trade-amount18 order-output-max18)"
    // end calculate order
    ";";

bytes constant RAINSTRING_HANDLE_IO_BUY =
// context 4 4 aliased by output-vault-balance-decrease() is the vault outputs as absolute values.
// context 2 0 aliased by calculated-max-output() is the calculated output as decimal 18.
// USDT is the output which is decimal 6 natively so we need to scale it.
    ":ensure<9>(greater-than-or-equal-to(output-vault-balance-decrease() decimal18-scale-n<6>(calculated-max-output())));";

function rainstringBuy() pure returns (bytes memory) {
    return bytes.concat(
        RAINSTRING_OB_SUBPARSER_PRELUDE,
        RAINSTRING_PRELUDE,
        RAINSTRING_CALCULATE_ORDER_BUY,
        RAINSTRING_HANDLE_IO_BUY,
        RAINSTRING_JITTERY_BINOMIAL,
        RAINSTRING_ENSURE_COOLDOWN,
        RAINSTRING_TARGET_USDT,
        RAINSTRING_UD_RATIO
    );
}

bytes constant SELL_ROUTE =
//offset
    hex"0000000000000000000000000000000000000000000000000000000000000020"
    //stream length
    hex"0000000000000000000000000000000000000000000000000000000000000042"
    //command 2 = processUserERC20
    hex"02"
    //token address
    hex"692AC1e363ae34b6B489148152b12e2785a3d8d6"
    //number of pools
    hex"01"
    // pool share
    hex"ffff"
    // pool type
    hex"00"
    // pool address
    hex"6777DBf38f67B448174412bAaF21F38e058b1f4B"
    // direction 1
    hex"01"
    // to
    hex"0D7896d70FE84e88CC8e8BaDcB14D612Eee4Bbe0"
    // padding
    hex"000000000000000000000000000000000000000000000000000000000000";

bytes constant BUY_ROUTE = //offset
    hex"0000000000000000000000000000000000000000000000000000000000000020"
    //stream length
    hex"0000000000000000000000000000000000000000000000000000000000000042"
    //command 2 = processUserERC20
    hex"02"
    //token address
    hex"c2132d05d31c914a87c6611c10748aeb04b58e8f"
    // number of pools
    hex"01"
    // pool share
    hex"ffff"
    // pool type
    hex"00"
    // pool address
    hex"6777DBf38f67B448174412bAaF21F38e058b1f4B"
    // direction 0
    hex"00"
    // to
    hex"0D7896d70FE84e88CC8e8BaDcB14D612Eee4Bbe0"
    // padding
    hex"000000000000000000000000000000000000000000000000000000000000";

