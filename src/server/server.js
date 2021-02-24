import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Status Codes to be used for flight status codes
const StatusCodes = [0, 10, 20, 30, 40, 50];

// ORACLE Registration and subscription to events
let oracleSubscriptions = new Array();

web3.eth.getAccounts().then(accs => {

    let accounts = accs;

    let registrationFee = web3.utils.toWei("1", "ether");

    // Registration of 20 Oracles
    for(let index = 20; index <= 39; index++) {
        console.log("Adding Oracle [" + index + "] with address {" + accounts[index] + "}");
        console.log("Registration Fee is: " + registrationFee+ " Wei");

        flightSuretyApp.methods
            .registerOracle()
            .send({from:accounts[index], value:registrationFee, gas:3000000}, (error, result) => {
                flightSuretyApp.methods
                    .getMyIndexes()
                    .call({from:accounts[index]}, (error, result) => {
                        oracleSubscriptions[index] = result;
                        console.log("Oracle [" + index + "] subscribed events {" + oracleSubscriptions[index] + "}");
                    });
            });
    }

});


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)

    for(let index = 20; index <= 39; index++) {
        // Every Oracle must have an active subscription
        if(!oracleSubscriptions[index]) {
            console.error("Oracle [" + index + "] has no subscriptions.");
            break;
        }

        var requestedIndex = event.returnValues['index'];
        var statusCode = randomSelectStatusCode();

        var hasActiveSubscription = (
            oracleSubscriptions[index][0] == requestedIndex
         || oracleSubscriptions[index][1] == requestedIndex
         || oracleSubscriptions[index][2] == requestedIndex
        )

        if(hasActiveSubscription) {

            console.log(
                "Oracle [", index, "]",
                "has an active subscription for index",
                "{", requestedIndex, "}",
                "and returns StatusCode (", statusCode, "):"
            );

            var oracleResponse = [requestedIndex,
                event.returnValues['airline'],
                event.returnValues['flight'],
                event.returnValues['timestamp'],
                statusCode];

            console.log("  .. calling submitOracleResponse("+ oracleResponse + ")");

            flightSuretyApp.methods.submitOracleResponse(
                requestedIndex,
                event.returnValues['airline'],
                event.returnValues['flight'],
                event.returnValues['timestamp'],
                statusCode
            )
        }
    }

});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

function randomSelectStatusCode() {
    let min = 0;
    let max = 5;
    var ind = Math.floor(Math.random() * (max - min + 1)) + min;
    return StatusCodes[ind];
}

export default app;
