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

# Address corresponding to ledger wallet.
SIGNER_ADDRESS= 

# Derivation path index(required). This is the mnemonic index corresponding to the above address of your ledger wallet.
# Default set to 0.
MNEMONIC_INDEX=0
```

## Deploy Rain Contracts
```sh
source .env && forge script script/DeployRainContracts.s.sol:DeployRainContracts --legacy --verify --rpc-url $RPC_URL_ETH  --etherscan-api-key ETHERSCAN_API_KEY --sender $SIGNER_ADDRESS --ledger --mnemonic-indexes $MNEMONIC_INDEX --broadcast
```
- After the contracts are deployed populate the remaining feilds in .env file
```sh
# Rain Contract Addresses.To be populated after the contracts are deployed.
PARSER=
EXPRESSION_DEPLOYER=
ORDERBOOK_SUBPARSER=
UNISWAP_WORDS=
```

## Add Orders
```sh
source .env && forge script script/OrderBookNPE2.s.sol:AddTrendRefillStratOrder --sig "run(address, uint256)" --sender $SIGNER_ADDRESS --rpc-url $RPC_URL_ETH --ledger --mnemonic-indexes $MNEMONIC_INDEX {orderBookAddress} {vaultId} --broadcast
```

## Deposit Tokens 
```sh
source .env && forge script script/OrderBookNPE2.s.sol:Deposit --sig "run(address, address, uint256, uint256)" --sender $SIGNER_ADDRESS --rpc-url $RPC_URL_ETH --ledger --mnemonic-indexes $MNEMONIC_INDEX {orderBookAddress} {token} {vaultId} {amount} --broadcast
```

## Withdraw Tokens
```sh
source .env && forge script script/OrderBookNPE2.s.sol:Withdraw --sig "run(address, address, uint256, uint256)" --sender $SIGNER_ADDRESS --rpc-url $RPC_URL_ETH --ledger --mnemonic-indexes $MNEMONIC_INDEX {orderBookAddress} {token} {vaultId} {amount} --broadcast
```

## Remove Orders
```sh
source .env && forge script script/OrderBookNPE2.s.sol:RemoveOrder --sig "run(address, string memory)()" --sender $SIGNER_ADDRESS --rpc-url $RPC_URL_ETH --ledger --mnemonic-indexes $MNEMONIC_INDEX {orderBookAddress} {txHash} --broadcast
```