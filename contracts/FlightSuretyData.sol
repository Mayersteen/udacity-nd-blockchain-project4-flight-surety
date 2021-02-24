pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Migrations.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Threshold when Multi-Party-Consensus gets activated
    uint256 private constant MPC_THRESHOLD = 5;

    // Maximum amount that an insurance can cost
    uint256 private constant MAX_INSURANCE_PRICE = 1 ether;

    // Minimum amount that is required to fund an airline in the contract
    uint256 private constant MIN_FUNDING_AMOUNT = 10 ether;

    // Account used to deploy contract
    address private contractOwner;

    // Blocks all state changes throughout the contract if false
    bool private operational = true;

    // Number of overall airlines.
    uint256 private allAirlinesCount = 0;

    // Number of airlines that are part of the contract.
    uint256 private registeredAirlinesCount = 0;

    // Number of airlines that have provided the funding of 10 ETH.
    uint256 private fundedAirlinesCount = 0;

    // Registration Queue
    uint256 private registrationQueue;

    // Struct that represents an airline.
    struct Airline{
        string name;
        address wallet;
        bool isRegistered;
        bool isFunded;
    }

    // Struct that represents votes
    struct Vote{
        address memberRequest;
        uint256 votes;
        bool success;
        mapping(address => bool) hasVoted;
        uint256 memberCount;
        bool mpcRequired;
        uint256 threshold;
    }

    // Struct that represents an Insurance
    struct Insurance{
        uint256 value;
        address customer;
        string flight;
        bytes32 flightKey;
        address airline;
        uint256 timestamp;
        //bool processed;
    }

    // Mapping to map Insurance to passengers
    //mapping(address => Insurance) private insurances;
    // TODO: Changed the mapping to a multi-mapping - need to ensure that all use is adapted accordingly.
    mapping(bytes32 => Insurance) private insurances;

    // Maps flight key to status code and states true if the flight is late (code 20) due to an airline error,
    // false otherwise. If this is true, an insurance payout is granted, otherwise not.
    mapping(bytes32 => bool) private flightLateAirline;

    // Contract funding to stay self-sustaining in case of many delayed flights
    mapping(address => uint256) private funding;

    // Credits per insured passenger
    mapping(address => uint256) private credits;

    // Mapping to store votingResults for addresses
    mapping(address => Vote) private votes;

    // Mapping to store Airlines
    mapping(address => Airline) private airlines;

    // Mapping for authorized callers
    mapping(address => bool) private authorizedCallers;

    // Multi-Party Consensus
    address[] multiCalls = new address[](0);

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    // Access Control Events
    event CallerAuthorized(address caller);

    // Airline Events
    event AirlineAvailable(address airlineAddress);
    event AirlineRegistered(address airlineAddress, bool isRegistered);
    event AirlineFunded(address airlineAddress, bool isFunded, uint256 funding);
    event AirlineInRegistrationQueue(address airlineAddress);
    event AirlineRemovedFromRegistrationQueue(address airlineAddress);
    event DebugAirlineFunds(address airline, uint256 funding);
    event DebugFundingReduced(address airline, uint256 amount, uint256 funds);

    // Voting Events
    event VoteCounted(address votedBy, address votedFor, bool voting);
    event VotingSuccessful(address airlineAddress, uint256 threshold, uint256 numVotes);

    // Flight Events
    event FlightLateAirline(bytes32 flightKey);

    // Insurance Events
    event InsurancePurchased(address customer, bytes32 flightKey, uint256 amount);
    event InsureeCredited(address customer, bytes32 flightKey, uint256 amount);
    event InsuranceDeleted(bytes32 flightKey);

    /********************************************************************************************/
    /*                                         CONSTRUCTOR                                      */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(
        address initialAirlineAddress
    )
        public
    {
        contractOwner = msg.sender;

        airlines[initialAirlineAddress] = Airline({
            name:"Lufthansa",
            wallet:initialAirlineAddress,
            isRegistered:true,
            isFunded:false
        });

        // emit Events
        emit AirlineAvailable(initialAirlineAddress);
        emit AirlineRegistered(initialAirlineAddress, airlines[initialAirlineAddress].isRegistered);

        // Increase the registered airlines counter by 1.
        registeredAirlinesCount = registeredAirlinesCount.add(1);
        allAirlinesCount = allAirlinesCount.add(1);

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the "Airline" account is registered.
    */
    modifier requireAirlineIsRegistered(address _address)
    {
        require(airlines[_address].isRegistered == true, "Airline is not registered.");
        _;
    }

    /**
    * @dev Modifier that requires the "Airline" account is funded.
    */
    modifier requireAirlineIsFunded(address _address)
    {
        require(airlines[_address].isFunded == true, "Airline is not funded.");
        _;
    }

    /**
    * @dev Modifier that requires the "Caller" to be authorized.
    */
    modifier requireAuthorizedCaller(address _address) {
        require(authorizedCallers[_address] == true, "Caller is not authorized to call this data contract");
        _;
    }

    /**
    * @dev Modifier that ensures that only "one vote" per airline is possible
    */
    modifier requireFirstVote(address _voteBy, address _voteFor) {
        require(votes[_voteFor].hasVoted[_voteBy] == false,
            "Only one vote per Airline is possible per memberRequest"
        );
        _;
    }

    /**
    * @dev Modifier that requires an active memberRequest.
    */
    modifier requireActiveMemberRequest(address _address) {
        require(votes[_address].memberRequest != address(0),
            "A memberRequest must be available before a vote can be triggered"
        );
        _;
    }

    /**
    * @dev Modifier that requires an active memberRequest.
    */
    modifier requireMPCThresholdReached(address _address) {
        require(votes[_address].mpcRequired == true,
            "Voting for a memberRequest can only be triggered if MPC is required."
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Returns the cap of a single insurance
    *
    * @return Maximum Insurance Price as uint256
    */
    function getInsuranceCap() external pure returns (uint256) {
        return MAX_INSURANCE_PRICE;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        public
        view
        returns (bool)
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(
        bool mode
    )
        external
        requireContractOwner
    {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    /**
    * @dev Sets contract addresses that are allowed to call into this smart contract.
    */
    function authorizeCaller(
        address applicationContractAddress
    )
        public
        requireContractOwner
        requireIsOperational
    {
        require(applicationContractAddress != address(0), "applicationContractAddress must not be [0x0]");
        authorizedCallers[applicationContractAddress] = true;

        emit CallerAuthorized(applicationContractAddress);
    }

    /**
         * @dev Return the requested airline.
         */
    function getAirline(
        address _address
    )
        public
        view
        returns (
            string _name,
            address _wallet,
            bool _isRegistered,
            bool _isFunded
        )
    {
        _name = airlines[_address].name;
        _wallet = airlines[_address].wallet;
        _isRegistered = airlines[_address].isRegistered;
        _isFunded = airlines[_address].isFunded;
    }

    /**
     * @dev Returns true if the Airline is registered, otherwise false.
     */
    function isAirlineRegistered(
        address _address
    )
        external
        view
        returns(bool)
    {
        return airlines[_address].isRegistered;
    }

    /**
     * @dev Returns true if the Airline is funded, otherwise false.
     */
    function isAirlineFunded(
        address _address
    )
        external
        view
        returns(bool)
    {
        return airlines[_address].isFunded;
    }

    /**
     * @dev Returns true if the calling address is authorized.
     */
    function isCallerAuthorized(
        address _address
    )
        public
        view
        returns(bool)
    {
        return authorizedCallers[_address];
    }

    /**
     * @dev Returns the votes for an address
     */
    function getVotingCount(
        address _address
    )
        external
        view
        requireIsOperational
        returns(uint256)
    {
        return (votes[_address].votes);
    }

    /**
     * @dev Returns the votes for an address
     */
    function getVotingResult(
        address _address
    )
    external
    view
    requireIsOperational
    returns(bool)
    {
        return (votes[_address].success);
    }

    /**
     * @dev Returns the votes for an address
     */
    function getVote(
        address _address
    )
        external
        view
        returns(uint256, uint256, uint256, bool)
    {
        return (
            votes[_address].memberCount,
            votes[_address].votes,
            votes[_address].threshold,
            votes[_address].success
        );
    }

    /**
     * @dev Returns the number of airlines - registered and unregistered
     */
    function getOverallAirlineCount()
        external
        view
        returns(uint256)
    {
        return allAirlinesCount;
    }

    /**
     * @dev Returns the number of registered airlines
     */
    function getRegisteredAirlinesCount()
        external
        view
        returns(uint256)
    {
        return registeredAirlinesCount;
    }

    /**
     * @dev Returns the length of the registration queue.
     */
    function getRegistrationQueueLength()
    external
    view
    returns(uint256)
    {
        return registrationQueue;
    }

    /**
    * @dev Get status for a flight - true: if the airline caused the delay, false: otherwise
    */
    function getFlightStatus(bytes32 flightKey) external view returns(bool) {
        return flightLateAirline[flightKey];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Sets status for a flight - true: if the airline caused the delay, false: otherwise
    */
    function setFlightStatus(
        bytes32 flightKey,
        bool status
    )
        external
    {
        flightLateAirline[flightKey] = status;
        emit FlightLateAirline(flightKey);
    }

    /**
     * @dev Allows airlines to vote for new members.
     */
    function voteForAirlineRegistration(
        address _address,
        bool _vote
    )
        external
        requireAirlineIsRegistered(msg.sender)
        requireAirlineIsFunded(msg.sender)
        requireFirstVote(msg.sender, _address)
        requireActiveMemberRequest(_address)
        requireMPCThresholdReached(_address)
    {
        // Voting can only happen when the vote is still open (not successful)
        require(votes[_address].success == false,
            "Voting must not be successful when voteForAirlineRegistration is called"
        );

        // Only increase the votes counter if the calling airline gives a positive vote
        if(_vote == true) {
            votes[_address].votes = votes[_address].votes.add(1);
        }

        // To avoid double voting set hasVoted to true.
        votes[_address].hasVoted[msg.sender] = true;

        emit VoteCounted(msg.sender, _address, _vote);

        if(votes[_address].votes >= votes[_address].threshold) {
            // Vote was successful
            votes[_address].success = true;
            emit VotingSuccessful(_address, votes[_address].threshold, votes[_address].votes);

            airlines[_address].isRegistered = true;
            registeredAirlinesCount = registeredAirlinesCount.add(1);
            emit AirlineRegistered(_address, true);

            registrationQueue = registrationQueue.sub(1);
            emit AirlineRemovedFromRegistrationQueue(_address);
        }

    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(
        string _name,
        address _address,
        address _invitedBy
    )
        external
        requireAuthorizedCaller(msg.sender)
        requireAirlineIsRegistered(_invitedBy)
        requireAirlineIsFunded(_invitedBy)
    {
        // Ensure that the airline was not yet registered.
        require(airlines[_address].wallet == address(0), "Airline must not be registered");

        // Increase the registered airlines counter by 1.
        allAirlinesCount = allAirlinesCount.add(1);
        emit AirlineAvailable(_address);

        // If less than 5 airlines are registered, register the airline without voting.
        if (registeredAirlinesCount < MPC_THRESHOLD) {

            airlines[_address] = Airline({
                name:_name,
                wallet:_address,
                isRegistered:true,
                isFunded:false
            });

            registeredAirlinesCount = registeredAirlinesCount.add(1);
            emit AirlineRegistered(_address, true);

            // Add artificial voting result
            votes[_address] = Vote({
                memberRequest:_address,
                votes:1,
                success:true,
                mpcRequired:false,
                memberCount:registeredAirlinesCount,
                threshold:1
            });

            votes[_address].hasVoted[msg.sender] = true;

            emit VoteCounted(msg.sender, _address, true);
            emit VotingSuccessful(_address, 1, 1);
        }
        else {
            // Add Airline to the registration Queue.
            registrationQueue = registrationQueue.add(1);
            emit AirlineInRegistrationQueue(_address);

            // Vote
            votes[_address] = Vote({
                memberRequest:_address,
                votes:1,
                success:false,
                mpcRequired:true,
                memberCount:registeredAirlinesCount,
                threshold:registeredAirlinesCount.div(2)
            });

            // The inviting Airline automatically votes for the invitee
            votes[_address].hasVoted[_invitedBy] = true;
            emit VoteCounted(msg.sender, _address, true);
        }
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund(
        address _address
    )
        external
        payable
        requireIsOperational
        requireAirlineIsRegistered(_address)
    {
        require(msg.value >= MIN_FUNDING_AMOUNT, "Not enough funding");

        // Adjust funding and allow additional funding
        uint256 _funding = funding[_address];
        _funding = _funding.add(msg.value);
        funding[_address] = _funding;

        airlines[_address].isFunded = true;

        fundedAirlinesCount = fundedAirlinesCount.add(1);
        multiCalls.push(_address);

        emit AirlineFunded(_address, airlines[_address].isFunded, msg.value);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyInsurance(
        address airline,
        string flight,
        uint256 timestamp,
        bytes32 flightKey,
        address sender
    )
        external
        payable
    {
        // Ensure that the max price is not exceeded
        require(msg.value <= MAX_INSURANCE_PRICE, "Data: Insurance amount must be <= MAX_INSURANCE_PRICE");

        // Ensure that the selected flight exists
        // TODO: Not required as this exercise uses pre-defined flight numbers. In a real scenario it would be mandatory.

        insurances[flightKey].customer = sender;
        insurances[flightKey].flightKey = flightKey;
        insurances[flightKey].value = msg.value;
        insurances[flightKey].airline = airline;
        insurances[flightKey].flight = flight;
        insurances[flightKey].timestamp = timestamp;

        emit InsurancePurchased(sender, flightKey, msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsuree(
        address _airline,
        string _flight,
        uint256 _timestamp
    )
        external
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);

        require(flightLateAirline[flightKey], "Delay must be caused by the airline.");

        // Calculate amount hat needs to be credited to the insuree
        uint256 amount = insurances[flightKey].value;
        require(amount > 0, "Insurance amount must be > 0");
        amount = amount.mul(15).div(10);

        emit InsureeCredited(insurances[flightKey].customer, flightKey, amount);
        emit DebugAirlineFunds(_airline, funding[_airline]);

        // remove amount from airlines funding
        address airline = insurances[flightKey].airline;
        require(funding[airline] >= amount, "Airline must have sufficient funds to credit insuree");
        funding[airline] = funding[airline].sub(amount);

        emit DebugFundingReduced(airline, amount, funding[airline]);

        // credit the calculated amount
        uint256 currentCredits = credits[insurances[flightKey].customer];
        credits[insurances[flightKey].customer] = currentCredits.add(amount);
        emit InsureeCredited(insurances[flightKey].customer, flightKey, amount);

        // delete the insurance entry
        delete insurances[flightKey];
        delete flightLateAirline[flightKey];
        emit InsuranceDeleted(flightKey);
    }

    /**
     *  @dev Returns the credits balance of msg.sender
    */
    function checkBalance(address sender) external view returns (uint256){
        return credits[sender];
    }

    function getInsuranceStatus(bytes32 flightKey) external view returns(bool) {
        if (insurances[flightKey].customer != address(0)) {
            return true;
        }
        return false;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
    */
    function pay(
        address sender
    )
        external
    {
        require(credits[sender] > 0, "Insuree must have more than 0 credits in order to receive a payout");

        // In a real scenario we would be required to also ensure that each airline has sufficient funding to serve
        // all potential payouts. This is not part of the exercise.

        // Transfer accrued credits to the owner.
        uint256 amount = credits[sender];
        credits[sender] = 0;
        sender.transfer(amount);
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

}