
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests:Commons', async (accounts) => {

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
    it(`(airline contract initialization) constructor registers first airline`, async function() {
        let airline = await config.flightSuretyData.getAirline.call(config.firstAirline);
        assert.equal(airline[0], "Lufthansa", "Airline name is not correct");
        assert.equal(airline[2], true, "Airline isRegistered must be true");
        assert.equal(airline[3], false, "Airline isFunded must be false");

        let qLen = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLen, 0, "registrationQueue must be empty.");

        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Contract must be Operational.");

        // fund Airline
        let errorCatched = false;
        try
        {
            await config.flightSuretyData.fundAirline(
                config.firstAirline,
                {
                    from:config.owner,
                    value:10000000000000000000 // 10 Ether in Wei
                }
            );
        }
        catch(e) {
            console.log(e);
            errorCatched = true;
        }
        assert.equal(errorCatched, false, "Funded Airline must be able to register an airline. (registerAirline->error)");

        let airlineFundingStatus = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);
        assert.equal(airlineFundingStatus, true, "Airline isFunded must be true.");

    });

    it(`(contract access) registerAirline can be called only from AppContract`, async function() {

        let unauthorizedCaller = false;
        try
        {
            await config.flightSuretyData.registerAirline(
                "ABC Airline",
                accounts[3],
                config.firstAirline,
                {
                    from: config.testAddresses[3]
                }
            );
        }
        catch(e) {
            unauthorizedCaller = true;
        }

        assert.equal(unauthorizedCaller, true, "registerAirline must only be callable by contract members.");
    });

});
