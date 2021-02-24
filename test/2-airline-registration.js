
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests:Airline Registration', async (accounts) => {

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

    it(`(airline registration) Unregistered airline cannot registerAirline`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        // Ensure that precondition is met: Inviting Airline is not
        let invitingAirlineIsRegistered = await config.flightSuretyData.isAirlineRegistered.call(
            accounts[3]
        );
        assert.equal(invitingAirlineIsRegistered, false, "Inviting Airline must not be registered.");

        let authorizedCaller = true;
        try
        {
            await config.flightSuretyData.registerAirline(
                "ABC Airline",
                accounts[3],
                accounts[4],
                {
                    from:config.flightSuretyApp.address
                }
            );
        }
        catch(e) {
            authorizedCaller = false;
        }

        assert.equal(authorizedCaller, false, "Unregistered Airline must not be able to call registerAirline.");

        let qLen = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLen, 0, "registrationQueue must be [0].");
    });

    it(`(airline registration) Unfunded airline cannot registerAirline`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        // Ensure that the inviting Airline is registered.
        let invitingAirlineIsRegistered = await config.flightSuretyData.isAirlineRegistered.call(
            config.firstAirline
        );
        assert.equal(invitingAirlineIsRegistered, true, "Inviting Airline must be registered.");

        // Ensure that precondition is met: Inviting Airline is not funded
        let invitingAirlineIsFunded = await config.flightSuretyData.isAirlineFunded.call(
            config.firstAirline
        );
        assert.equal(invitingAirlineIsFunded, false, "Inviting Airline must not be funded.");

        // Ensure that the initial registrationQueue length is [0].
        let qLenPre = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPre, 0, "registrationQueue length must be [0]");

        // Ensure that airline to be registered is not registered.
        let test = await config.flightSuretyData.getAirline(accounts[3]);
        assert.equal(test[1], 0, "Address of unregistered airline must be [0].");

        // registered airline can add new members to the registrationQueue.
        let errorCatched = false;
        try
        {
            await config.flightSuretyApp.registerAirline(
                "ABC Airline",
                accounts[3],
                {
                    from:config.firstAirline
                }
            );
        }
        catch(e) {
            errorCatched = true;
        }
        assert.equal(errorCatched, true, "Unfunded Airline must not be able to register an airline.");

        let qLenPost = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPost, 0, "registrationQueue length must be [0] as multi-party consensus is not active in this test.");
    });

    it(`(airline registration) registerAirline can be called by a funded airline`, async function() {

        // Ensure that the calling contract address is authorized.
        let callerAuthorizedStatus = await config.flightSuretyData.isCallerAuthorized.call(
            config.flightSuretyApp.address
        );
        assert.equal(callerAuthorizedStatus, true, "Caller must be authorized to access the Data contract.");

        // Ensure that the inviting Airline is registered.
        let invitingAirlineIsRegistered = await config.flightSuretyData.isAirlineRegistered.call(
            config.firstAirline
        );
        assert.equal(invitingAirlineIsRegistered, true, "Inviting Airline must be registered.");

        // Fund Airline
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

        // Ensure that precondition is met: Inviting Airline is funded
        let invitingAirlineIsFunded = await config.flightSuretyData.isAirlineFunded.call(
            config.firstAirline
        );
        assert.equal(invitingAirlineIsFunded, true, "Inviting Airline must be funded.");

        // Ensure that the initial registrationQueue length is [0].
        let qLenPre = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPre, 0, "registrationQueue length must be [0]");

        // Ensure that airline to be registered is not registered.
        let test = await config.flightSuretyData.getAirline(accounts[3]);
        assert.equal(test[1], 0, "Address of unregistered airline must be [0].");

        // registered airline can add new members to the registrationQueue.
        let errorCatched = false;
        try
        {
            await config.flightSuretyApp.registerAirline(
                "NewAir",
                accounts[3],
                {
                    from:config.firstAirline
                }
            );
        }
        catch(e) {
            console.log(e);
            errorCatched = true;
        }
        assert.equal(errorCatched, false, "Funded Airline must be able to register an airline. (registerAirline->error)");

        let qLenPost = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPost, 0, "registrationQueue length must be [0] as multi-party consensus is not active in this test.");
    });

});
