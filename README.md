# Auctchain (Solidity, Truffle, Web3)

Ethereum Auction dApp.
This project needs :
  - Truffle Framework
  - Ganache
  - Metamask (Wallet)

## Running
The Web3 RPC location will be picked up from the `truffle.js` file.

0. Clone this repo
0. `npm install -g truffle`
0. Make sure Ganache opened and running on its default port. Then:
  - `truffle compile` - Create artifacts of the contract.
  - `truffle migrate --reset` - Migrate the artifacts to local server.

You will need 'npm run dev', the app will be available at <http://localhost:3001> or use XAMPP.
