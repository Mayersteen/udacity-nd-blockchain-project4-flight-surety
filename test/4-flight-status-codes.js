
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests:Flight Status Codes', async (accounts) => {

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

    it(`(flight status) Delay caused by the airline is correctly flagged as (true) in getFlightStatus`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        let airline = accounts[1];
        let flight = "LH123";
        let timestamp = 1613495849;
        let code = 20;

        await config.flightSuretyApp.processFlightStatus(airline, flight, timestamp, code);

        let flightStatus = await config.flightSuretyApp.getFlightStatus(airline, flight, timestamp);

        assert.equal(flightStatus, true, "getFlightStatus must be true as the flight was delayed by the airline.")

    });


    it(`(flight status) Delay NOT caused by the airline is correctly flagged as (false) in getFlightStatus`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must return authorized to access the Data contract.");

        let airline = accounts[1];
        let flight = "LH123";
        let timestamp = 1613495850;
        let code = 30;

        await config.flightSuretyApp.processFlightStatus(airline, flight, timestamp, code);

        let flightStatus = await config.flightSuretyApp.getFlightStatus(airline, flight, timestamp);

        assert.equal(flightStatus, false, "getFlightStatus must return false as the flight was delayed by the airline.")

    });

});
