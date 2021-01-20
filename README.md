# Project Rubrics
* Separation of Concerns, Operational Control and "Fail Fast".
    + **Smart Contract Separation**
        + Smart Contract Code is separated into multiple contracts.
            1) FlightSuretyData.sol for data persistance.
            2) FlightSuretyApp.sol for app logic and oracles code.
    + **Dapp Created and Used for Contract Calls**
        + A Dapp client has been created and is used for triggering contract calls. Client can be launched with "npm run
          dapp" and is available at http://localhost:8000.
            1) Passenger can purchase insurance for flight.
            2) Trigger contract to request flight status update.
    + **Oracle Server Application**
        + A server app has been crated for simulating oracle behavior. Server can be launched with "npm run server"
    + **Operational status control is implemented in contracts**
        + Student has implemented operational status control.
    + **Fail Fast Contract**
        + Contract functions "fail fast" by having a majority of "require()" calls at the beginning of function body.
* Airlines
    + **Airline Contract Initalization**
        + First airline is registered when contract is deployed.
    + **Multiparty Consensus**
        + Only existing airline may register a new airline until there are at least four airlines registered.
          Demonstrated either with Truffle test or by making call from client.
        + Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines.
          Demonstrated either with Truffle test or by making call from the client.
    * **Airline Ante**
        + Airline can be registered, but does not participate in contract until it submits funding of 10 ether. 
          Demonstrated either with Truffle test or by making call from client Dapp.
* Passengers
    + **Passenger Airline Choice**
        + Passengers can choose from a fixed list of flight numbers and departure that are defined in the Dapp client.
    + **Passenger Payment**
        + Passengers may pay up to 1 ether for purchasing flight insurance.
    + **Passenger Repayment*
        + If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid.
    + **Passenger Withdraw**
        + Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout.
    + **Insurance Payouts**
        + Insurance payouts are not sent directly to passenger's wallet.
* Oracles (Server App)
    + **Functioning Oracle**
        + Oracle functionality is implemented in the server app.
    + **Oracle Initialization**
        + Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
    + **Oracle Updates**
        + Update flight status requests from client Dapp result in OracleRequest event emitted by Smart Contract that is
          captured by the server (displays on console and handled in code).
    + **Oracle Functionality**
        + Server will loop through all registered oracles, identify whose oracles for which the OracleRequest event
          applies, and respond by calling into FlightSuretyApp contract with random status code of:
          Unknown (0), On Time (10) or Late Airline (20), Late Weather (30), Late Technical (40), or Late Other(50).
    
# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding
(using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)