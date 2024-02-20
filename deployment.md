## Feb 20,2024 update.
- Updated the strat params. To remove old orders and add new ones with update params : 
```sh
source .env && forge script script/OrderBookNPE2.s.sol:RemoveOrder --sig "run(address, string memory)()" --rpc-url $RPC_URL_ETH 0xf1224A483ad7F1E9aA46A8CE41229F32d7549A74 0x94e8925a25ba78755812d2c1bd02ebcf23a038a560052c62600072e98db39804 --broadcast
```
```sh
source .env && forge script script/OrderBookNPE2.s.sol:RemoveOrder --sig "run(address, string memory)()" --rpc-url $RPC_URL_ETH 0xf1224A483ad7F1E9aA46A8CE41229F32d7549A74 0xa030c86277f8a311cd569f24a15f314f427450cd8b1fc2224e0b6965b373f7e7 --broadcast
```
```sh
source .env && forge script script/OrderBookNPE2.s.sol:AddTrendRefillStratOrder --sig "run(address, uint256)" --rpc-url $RPC_URL_ETH 0xf1224A483ad7F1E9aA46A8CE41229F32d7549A74 1 --broadcast
```
## Prerequisite
- Install [git](https://git-scm.com/downloads)
- Install [Nix](https://nixos.org/download)
## Set Up
- Clone the repo
```sh
git clone https://github.com/h20liquidity/xblock.git
cd xblock
```
- Enter Dev shell
```
nix develop
```
- Forge Install
```
forge install
```
- Run Nix Preludes
```
nix run .#uniswap-prelude
nix run .#rainix-sol-prelude
cd lib/rain.orderbook/lib/rain.interpreter 
nix run .#i9r-prelude
cd ../../../../
```
## Update the env file
- Update the env file
```sh
# Ethereum Mainnet RPC URL
RPC_URL_ETH=

# Etherscan Api Key
ETHERSCAN_API_KEY=

# 0x prefixed private key for an account.
DEPLOYMENT_KEY=
```

## Deploy Rain Contracts
```sh
source .env && forge script script/DeployRainContracts.s.sol:DeployRainContracts --legacy --verify --rpc-url $RPC_URL_ETH  --etherscan-api-key ETHERSCAN_API_KEY --broadcast
```
- After the contracts are deployed populate the remaining feilds in .env file
```sh
# Rain Contract Addresses.To be populated after the contracts are deployed.
PARSER=
EXPRESSION_DEPLOYER=
ORDERBOOK_SUBPARSER=
UNISWAP_WORDS=
```
## Add Arb Contract and OrderBook to AMM list. 
- After all the contracts are deployed, the arb instance contract needs to be whitelisted, i.e the owner of the `LOCK` token contract needs to call the `setAutomatedMarketMakerPair(address account, bool value)` with boolean value set to true. Refer [here.](https://etherscan.io/address/0x922D8563631B03C2c4cf817f4d18f6883AbA0109#writeContract)
- Whitelist OrderBook Contract as well.
- This can be done by any tooling that the owner has or run the following foundry script. (Note that the `DEPLOYMENT_KEY` in the .env should correspond to contract owner's wallet for this script) : 
```sh
source .env && forge script script/LockToken.s.sol:LockAMMPair --sig "run(address, bool)" --rpc-url $RPC_URL_ETH {contractAddress} {boolValue} --broadcast
```

## Whitelist Order Owner wallet. 
- Next we need to whitelist the order owner wallet, i.e the wallet that will `addOrder` and `deposit` tokens.
- Owner to the `LOCK` contract can do this by any tooling by calling the `excludeFromLimits` function or can run the following script (Note that the `DEPLOYMENT_KEY` in the .env should correspond to contract owner's wallet for this script) : 
```sh
source .env && forge script script/LockToken.s.sol:LockExcludeFromList --sig "run(address, bool)" --rpc-url $RPC_URL_ETH {account} {boolValue} --broadcast
```

- **Make Sure all the .env variables are set and then can run the following commands as required**
## Add Orders
```sh
source .env && forge script script/OrderBookNPE2.s.sol:AddTrendRefillStratOrder --sig "run(address, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {vaultId} --broadcast
```

## Deposit Tokens 
```sh
source .env && forge script script/OrderBookNPE2.s.sol:Deposit --sig "run(address, address, uint256, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {token} {vaultId} {amount} --broadcast
```
- Note: Amount is fully denominated token amount

## Withdraw Tokens
```sh
source .env && forge script script/OrderBookNPE2.s.sol:Withdraw --sig "run(address, address, uint256, uint256)" --rpc-url $RPC_URL_ETH {orderBookAddress} {token} {vaultId} {amount} --broadcast
```
- Note: Amount is fully denominated token amount

## Remove Orders
```sh
source .env && forge script script/OrderBookNPE2.s.sol:RemoveOrder --sig "run(address, string memory)()" --rpc-url $RPC_URL_ETH {orderBookAddress} {txHash} --broadcast
```

## Deploy Subgraph.
Subgraph needs to be deployed for OrderBook Smart Contract.
Refer : https://github.com/rainlanguage/rain.orderbook/pull/50

## Update Digital Ocean Bot Instance
After the Subgraph is deployed. We can update the arb-bot environment variables. Following variables need to be updated : 
- `ORDERBOOK_ADDRESS` - Address of OrderBook
- `ARB_ADDRESS` - Arb Instance address
- `SUBGRAPH` - Subgraph url

Save the changes, bot gets redeployed with updated vars.