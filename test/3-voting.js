
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests:Voting and Multi-Party Consensus', async (accounts) => {

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

    it(`(voting) An unregistered airline cannot vote`, async function() {

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

        let exceptionThrown = false;
        try
        {
            await config.flightSuretyData.voteForAirlineRegistration(
                accounts[5],
                {
                    from:accounts[3]
                }
            );
        }
        catch(e) {
            exceptionThrown = true;
        }

        assert.equal(exceptionThrown, true, "Unregistered Airline must not be able to call vote.");

    });


    it(`(voting) An unfunded airline cannot vote`, async function() {
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
        let registrationStatus7 = await config.flightSuretyData.getAirline(accounts[7]);
        assert.equal(registrationStatus7[1], 0, "Address of unregistered airline must be [0].");

        // Ensure that airline to be registered is not registered.
        let registrationStatus8 = await config.flightSuretyData.getAirline(accounts[8]);
        assert.equal(registrationStatus8[1], 0, "Address of unregistered airline must be [0].");

        // Ensure that the inviting Airline is funded
        // Fund firstAirline
        let errorCatchedFundingInvitingAirline = false;
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
            errorCatchedFundingInvitingAirline = true;
        }
        assert.equal(
            errorCatchedFundingInvitingAirline,
            false,
            "Airline must be funded to participate in the voting process."
        );

        /* New Airlines are registered to simulate a voting situation.
         * airlines[7] will vote for the registration of airlines[8]
         */
        let errorCatchedRegistration = false;
        try
        {
            // Register 5 more airlines
            for(i=7; i<12; i++) {
                await config.flightSuretyApp.registerAirline(
                    "XYZ Airline",
                    accounts[i],
                    {
                        from:config.firstAirline
                    }
                );
            }
        }
        catch(e) {
            console.log(e);
            errorCatchedRegistration = true;
        }
        assert.equal(
            errorCatchedRegistration,
            false,
            "Funded Airline must be able to register an airline."
        );

        // Ensure that 6 airlines are present in the contract after the registration processes
        let numberOfExistingAirlines = await config.flightSuretyData.getOverallAirlineCount.call();
        assert.equal(
            numberOfExistingAirlines,
            6,
            "At this point 6 airlines must be known to the contract."
        )

        // Ensure that airline #5 [index 10] is registered
        let isAirlineFiveRegistered = await config.flightSuretyData.isAirlineRegistered.call(accounts[10]);
        assert.equal(isAirlineFiveRegistered, true, "Airline #5 must be registered as MPC is not active")

        // Ensure that airline #6 [index 11] is not registered
        let isAirlineAfterMPCIsActiveRegistered = await config.flightSuretyData.isAirlineRegistered.call(accounts[11]);
        assert.equal(isAirlineAfterMPCIsActiveRegistered, false, "Airline #6 must not be registered as MPC is active")

        // Ensure that the number of registered Airlines is 5 so that MPC gets activated
        let numberOfRegisteredAirlines = await config.flightSuretyData.getRegisteredAirlinesCount.call();
        assert.equal(numberOfRegisteredAirlines, 5, "Five airlines must be registered.");

        // One Airline must be in the registrationQueue
        let qLenPost = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPost, 1, "registrationQueue length must be [1] as multi-party consensus is active.");

        // Ensure that precondition is met: Inviting Airline is registered
        let votingAirlineRegistrationStatus = await config.flightSuretyData.isAirlineRegistered.call(
            accounts[7]
        );
        assert.equal(votingAirlineRegistrationStatus, true, "Voting Airline must be registered.");

        // Ensure that precondition is met: Voting Airline is not funded
        let votingAirlineFundingStatus = await config.flightSuretyData.isAirlineFunded.call(
            accounts[7]
        );
        assert.equal(votingAirlineFundingStatus, false, "Voting Airline must not be funded.");

        let exceptionThrownVote = false;
        try
        {
            await config.flightSuretyData.voteForAirlineRegistration(
                accounts[11],
                true,
                {
                    from:accounts[7]
                }
            );
        }
        catch(e) {
            exceptionThrownVote = true;
        }
        assert.equal(
            exceptionThrownVote,
            true,
            "Unfunded Airline must not be able to vote for new airlines joining the contract."
        );

    });


    it(`(multi-party consensus) A funded airline can vote and MPC works`, async function() {
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

        // Ensure that precondition is met: Inviting Airline is funded
        let invitingAirlineIsFunded = await config.flightSuretyData.isAirlineFunded.call(
            config.firstAirline
        );
        assert.equal(invitingAirlineIsFunded, true, "Inviting Airline must be funded.");

        // Ensure that the initial registrationQueue length is [1].
        let qLenPre = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPre, 1, "registrationQueue length must be [1]");

        // Ensure that 6 airlines are present in the contract after the registration processes
        let numberOfExistingAirlines = await config.flightSuretyData.getOverallAirlineCount.call();
        assert.equal(
            numberOfExistingAirlines,
            6,
            "At this point 6 airlines must be known to the contract."
        )

        // Ensure that airline #5 [index 10] is registered
        let isAirlineFiveRegistered = await config.flightSuretyData.isAirlineRegistered.call(accounts[10]);
        assert.equal(isAirlineFiveRegistered, true, "Airline #5 must be registered as MPC is not active")

        // Ensure that airline #6 [index 11] is not registered
        let isAirlineAfterMPCIsActiveRegistered = await config.flightSuretyData.isAirlineRegistered.call(accounts[11]);
        assert.equal(isAirlineAfterMPCIsActiveRegistered, false, "Airline #6 must not be registered as MPC is active")

        // Ensure that the number of registered Airlines is 5 so that MPC gets activated
        let numberOfRegisteredAirlines = await config.flightSuretyData.getRegisteredAirlinesCount.call();
        assert.equal(numberOfRegisteredAirlines, 5, "Five airlines must be registered.");

        // One Airline must be in the registrationQueue
        let qLenPost = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(qLenPost, 1, "registrationQueue length must be [1] as multi-party consensus is active.");

        // Fund firstAirline
        let errorCatchedFundingVotingAirline = false;
        try
        {
            for(j=7; j<11; j++) {
                await config.flightSuretyData.fundAirline(
                    accounts[j],
                    {
                        from:accounts[j],
                        value:10000000000000000000 // 10 Ether in Wei
                    }
                );
            }
        }
        catch(e) {
            console.log(e);
            errorCatchedFundingVotingAirline = true;
        }
        assert.equal(
            errorCatchedFundingVotingAirline,
            false,
            "Airlines must be funded to participate in the voting process."
        );

        // Ensure that precondition is met: Inviting Airline is registered
        let votingAirlineRegistrationStatus = await config.flightSuretyData.isAirlineRegistered.call(
            accounts[7]
        );
        assert.equal(votingAirlineRegistrationStatus, true, "Voting Airline must be registered.");

        // Ensure that precondition is met: Voting Airline is not funded
        let votingAirlineFundingStatus = await config.flightSuretyData.isAirlineFunded.call(
            accounts[7]
        );
        assert.equal(votingAirlineFundingStatus, true, "Voting Airline must be funded.");

        // VotingCount must be 1 before the voting starts, as the inviter implicitly votes "true"
        let preVotingCount = await config.flightSuretyData.getVotingCount(accounts[11]);
        assert.equal(preVotingCount, 1, "Airline must have [1] vote before voting starts.")

        // VotingResult must be false before voting starts
        let votingResultPreVote = await config.flightSuretyData.getVotingResult(accounts[11]);
        assert.equal(votingResultPreVote, false, "Vote success must be false before voting was successful.")

        let voteStructPreVote = await config.flightSuretyData.getVote(accounts[11]);
        assert.equal(voteStructPreVote[0], 5, "MemberCount must be 5");
        assert.equal(voteStructPreVote[1], 1, "Votes must be 1");
        assert.equal(voteStructPreVote[2], 2, "Threshold must be 2");
        assert.equal(voteStructPreVote[3], false, "Vote success must be false")

        let exceptionThrownVote = false;
        try
        {
            await config.flightSuretyData.voteForAirlineRegistration(
                accounts[11],
                true,
                {
                    from:accounts[7]
                }
            );
        }
        catch(e) {
            exceptionThrownVote = true;
        }
        assert.equal(
            exceptionThrownVote,
            false,
            "Funded Airline must be able to vote for new airlines joining the contract."
        );

        let voteStructPostVote = await config.flightSuretyData.getVote(accounts[11]);
        assert.equal(voteStructPostVote[0], 5, "MemberCount must be 5");
        assert.equal(voteStructPostVote[1], 2, "Votes must be 2");
        assert.equal(voteStructPostVote[2], 2, "Threshold must be 2");
        assert.equal(voteStructPostVote[3], true, "Vote success must be true")

        // registrationQueueLength must be 0 after successful voting
        let postVotingRegistrationQueueLength = await config.flightSuretyData.getRegistrationQueueLength.call();
        assert.equal(
            postVotingRegistrationQueueLength,
            0,
            "registrationQueue length must be [0] after vote was successful."
        );
    });

    it(`(multi-party consensus) Correct voting threshold is set when number of airlines increases`, async function() {

        let exceptionThrownVote = false;
        try
        {
            await config.flightSuretyApp.registerAirline(
                "HAU Airline",
                accounts[12],
                {
                    from:config.firstAirline
                }
            );
        }
        catch(e) {
            exceptionThrownVote = true;
        }
        assert.equal(
            exceptionThrownVote,
            false,
            "Airline registration must be successful"
        );

        // Ensure that the Vote Threshold increased to 3
        let votingStatus = await config.flightSuretyData.getVote(accounts[12]);
        assert.equal(votingStatus[0], 6, "MemberCount must be 6");
        assert.equal(votingStatus[1], 1, "Votes must be 1");
        assert.equal(votingStatus[2], 3, "Threshold must be 3");
        assert.equal(votingStatus[3], false, "Vote success must be false")

    });

});
