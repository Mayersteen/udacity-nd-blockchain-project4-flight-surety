
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests:Flight Insurance', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(
            config.flightSuretyApp.address,
            {
                from:config.owner
            }
        );
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    //TODO: Passengers can buy flight insurance

    //TODO: Flight insurance max price is considered

    //TODO: Flight insurance credits are provided when flight is late

    //TODO: Passenger can clain credits

});
