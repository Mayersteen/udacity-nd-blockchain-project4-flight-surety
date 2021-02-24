
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

    it(`(flight insurance) MAX_INSURANCE_AMOUNT is considered`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        let airline = accounts[1];
        let flight = "LH123";
        let timestamp = 1613495849;
        let insuree = accounts[2];

        let exceptionThrown = false;
        try
        {
            await config.flightSuretyApp.buyInsurance(
                airline,
                flight,
                timestamp,
                {
                    from:insuree,
                    value:2000000000000000000
                }
            );
        }
        catch(e) {
            exceptionThrown = true;
        }

        assert.equal(exceptionThrown, true, "Insurance amount cannot be greater than 1 ether.");

    });

    //TODO: Passengers can buy flight insurance

    it(`(flight insurance) Insurance can be purchased if amount is <= 1 ether`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        let airline = config.firstAirline;
        let flight = "LH123";
        let timestamp = 1613495850;
        let insuree = accounts[3];

        let insuranceStatusPre = await config.flightSuretyApp.checkInsuranceStatus(airline, flight, timestamp);
        assert.equal(insuranceStatusPre, false, "No insurance was purchased.")

        let exceptionThrown = false;
        try
        {
            await config.flightSuretyApp.buyInsurance(
                airline,
                flight,
                timestamp,
                {
                    from:insuree,
                    value:5000000000
                }
            );
        }
        catch(e) {
            exceptionThrown = true;
            console.log(e);
        }
        assert.equal(exceptionThrown, false, "Insurance can be purchased for a max amount of 1 ether.");

        let insuranceStatusPost = await config.flightSuretyApp.checkInsuranceStatus(airline, flight, timestamp);
        assert.equal(insuranceStatusPost, true, "Insurance was successfully purchased.")

    });

    it(`(flight insurance) Insuree is credited when flight is late`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        let errorCatchedFunding = false;
        try
        {
            await config.flightSuretyData.fund(
                config.firstAirline,
                {
                    from:config.owner,
                    value:10000000000000000000 // 10 Ether in Wei
                }
            );
        }
        catch(e) {
            console.log(e);
            errorCatchedFunding = true;
        }
        assert.equal(errorCatchedFunding, false, "Funded Airline must be able to register an airline. (registerAirline->error)");

        let airline = config.firstAirline;
        let flight = "LH123";
        let timestamp = 1613495851;
        let insuree = accounts[4];
        let code = 20;

        let insuranceStatusPre = await config.flightSuretyApp.checkInsuranceStatus(airline, flight, timestamp);
        assert.equal(insuranceStatusPre, false, "No insurance was purchased.")

        let exceptionThrown = false;
        try
        {
            await config.flightSuretyApp.buyInsurance(
                airline,
                flight,
                timestamp,
                {
                    from:insuree,
                    value:1000000000000000
                }
            );
        }
        catch(e) {
            exceptionThrown = true;
            console.log(e);
        }
        assert.equal(exceptionThrown, false, "Insurance can be purchased for a max amount of 1 ether.");

        let insuranceStatusPost = await config.flightSuretyApp.checkInsuranceStatus(airline, flight, timestamp);
        assert.equal(insuranceStatusPost, true, "Insurance was successfully purchased.")

        // Set status code of flight to 20 (airline fault)
        try {
            await config.flightSuretyApp.processFlightStatus(airline, flight, timestamp, code);
        } catch(e) {
            console.log(e);
        }
        let flightStatus = await config.flightSuretyApp.getFlightStatus(airline, flight, timestamp);
        assert.equal(flightStatus, true, "getFlightStatus must be true as the flight was delayed by the airline.")

        let balancePre = await config.flightSuretyApp.getInsureeBalance({from:insuree});
        assert.equal(balancePre, 0, "Insuree credit is initially set to 0.")

        let processFlightInsuranceException = false;
        try {
            await config.flightSuretyApp.processFlightInsurance(airline, flight, timestamp);
        } catch(e) {
            processFlightInsuranceException = true;
            console.log(e);
        }

        assert.equal(processFlightInsuranceException, false, "processFlightInsuranceException called successfully.");

        let balancePost = await config.flightSuretyApp.getInsureeBalance({from:insuree});
        assert.equal(balancePost, 1500000000000000, "Insuree was credited the correct amount.")

    });

    // This test builds upon the prior test and expects that the credits of the user were successfully stored in the
    // respective mapping. This test only focuses on the transfer transaction itself.
    it(`(flight insurance) Insuree can receive payout`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        let insuree = accounts[4];

        //let accountBalancePre = await web3.eth.getBalance(accounts[4]);
        //console.log("BALANCE Pre : " + accountBalancePre);

        let balancePre = await config.flightSuretyApp.getInsureeBalance({from:insuree});
        assert.equal(balancePre, 1500000000000000, "Account has the correct amount of credits.")

        let payoutException = false;
        try {
            await config.flightSuretyApp.getPayout(
                {
                    from: insuree
                }
            );
        } catch(e) {
            console.log(e);
            payoutException = true;
        }

        assert.equal(payoutException, false, "getPayout called successfully.");

        let balancePost = await config.flightSuretyApp.getInsureeBalance({from:insuree});
        assert.equal(balancePost, 0, "Payout successful, insuree credits were set to 0.")

        //let accountBalancePost = await web3.eth.getBalance(accounts[4]);
        //console.log("BALANCE Post: " + accountBalancePost);

    });

});
