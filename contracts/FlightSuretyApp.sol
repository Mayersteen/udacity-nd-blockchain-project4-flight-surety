pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string flight;
    }

    mapping(bytes32 => Flight) private flights;

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
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");
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
    * @dev Modifier that requires the "Airline" to be fund ed.
    */
    modifier requireAirlineIsFunded(address _address) {
        require(flightSuretyData.isAirlineFunded(_address), "Airline must be funded.");
        _;
    }

    /**
    * @dev Modifier that requires the "Airline" to be funded.
    */
    modifier requireAllowedToRegisterAirline() {
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Airline must be registered.");
        require(flightSuretyData.isAirlineFunded(msg.sender), "Airline must be funded.");
    _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(
        address flightSuretyDataAddress
    )
        public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(flightSuretyDataAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
        public
        view
        returns (bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Returns the flight status: true if the airline caused a delay, false otherwise
     */
    function getFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    )
        view
        external
        returns (bool)
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return flightSuretyData.getFlightStatus(flightKey);
    }

   /**
    * @dev Add an airline to the registration queue
    */   
    function registerAirline(
        string _name,
        address _address
    )
        external
        requireAllowedToRegisterAirline
    {
        // The airline to be registered must not be already registered
        require(!flightSuretyData.isAirlineRegistered(_address), "Airline is already registered");

        flightSuretyData.registerAirline(_name, _address, msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(
        address _airline,
        string _flight,
        uint256 _timestamp
    )
        external
    {
        bytes32 key = getFlightKey(_airline, _flight, _timestamp);

        flights[key] = Flight({
            isRegistered:true,
            statusCode: 0,
            updatedTimestamp: _timestamp,
            airline: _airline,
            flight: _flight
        });
    }

   /**
    * @dev Called after oracle has updated flight status. This is intended to be
    * triggered when the Oracle comes back with a result and it has to decide where
    * things go from here. If status code is not "20" then it needs to evaluate the
    * next steps. In most cases we only want to react to "20" and determine how much
    * the passengers who booked an insurance will get paid.
    */  
    function processFlightStatus(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
        public
    {
        // Calculate flight key
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        // Set flight status statusCode
        //flights[flightKey].statusCode = statusCode;

        // Set flight status if statusCode is 20
        if(statusCode == 20) {
            flightSuretyData.setFlightStatus(flightKey, true);
        }
    }

    /**
     * @dev Process insurance for a flight and credit the insuree
     */
    function processFlightInsurance(
        address airline,
        string flight,
        uint256 timestamp
    )
        public
    {
        flightSuretyData.creditInsuree(airline, flight, timestamp);
    }

    /**
     * @dev Generate a request for oracles to fetch flight information. This is triggered
     * from the UI (button click on the client Dapp) - this will then generate the
     * Event that will be generated for the Oracles to react to.
     */
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    )
        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    /**
     * @dev Customers buys an insurance for a flight.
     */
    function buyInsurance(
        address airline,
        string flight,
        uint256 timestamp
    )
        external
        payable
    {
        // The insurance price is capped by MAX_INSURANCE_PRICE, which is defined
        // in the flightSuretyData contract.
        require(msg.value <= flightSuretyData.getInsuranceCap(), "App: Insurance amount must be <= MAX_INSURANCE_PRICE");

        bytes32 key = getFlightKey(airline, flight, timestamp);

        // Call buyInsurance in the flightSuretyData contract and transfer the funds.
        flightSuretyData.buyInsurance.value(msg.value)(airline, flight, timestamp, key, msg.sender);

    }

    /**
     * @dev An insuree can request the payout of their accrued credits.
     */
    function getPayout() external {
        flightSuretyData.pay(msg.sender);
    }

    /**
     * @dev An insuree can request their accrued credits
     */
    function getInsureeBalance() public view returns (uint256) {
        return flightSuretyData.checkBalance(msg.sender);
    }

    /**
     * @dev Checks insurance status for a given flight
     */
    function checkInsuranceStatus(
        address airline,
        string flight,
        uint256 timestamp
    )
        public
        view
        returns (bool)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        return flightSuretyData.getInsuranceStatus(key);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle()
        external
        payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes()
        view
        external
        returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    )
        pure
        internal
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(
        address account
    )
        internal
        returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(
        address account
    )
        internal
        returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}
