
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

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

    //TODO: When Multi-Party Consensus Threshold is reached, Airlines are no longer automatically registered.

    //TODO: Multi-Party Consensus works when new airlines are being registered, uses voting

});
