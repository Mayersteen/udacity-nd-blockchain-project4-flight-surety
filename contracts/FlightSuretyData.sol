pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Migrations.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

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

    // Struct that represents an airline.
    struct Airline{
        string name;
        address wallet;
        bool isRegistered;
        bool isFunded;
    }

    // Mapping to store Airlines
    mapping(address => Airline) private airlines;

    // Mapping for authorized callers
    mapping(address => bool) private authorizedCallers;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineAvailable(address airlineAddress);
    event AirlineRegistered(address airlineAddress, bool isRegistered);
    event AirlineFunded(address airlineAddress, bool isFunded);
    event CallerAuthorized(address caller);

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
        registeredAirlinesCount.add(1);
        allAirlinesCount.add(1);
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
    modifier requireAirlinesIsRegistered(address _address)
    {
        require(airlines[_address].isRegistered == true, "Airline is not registered.");
        _;
    }

    /**
    * @dev Modifier that requires the "Airline" account is funded.
    */
    modifier requireAirlinesIsFunded(address _address)
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        public
        view
        returns(bool)
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
        operational = mode;
    }

    function authorizeCaller(address applicationContractAddress)
    public
    requireContractOwner
    requireIsOperational
    {
        require(applicationContractAddress != address(0));
        authorizedCallers[applicationContractAddress] = true;

        emit CallerAuthorized(applicationContractAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

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
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline()
        external
        pure
    {

    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy()
        external
        payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees()
        external
        pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay()
        external
        pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund()
        public
        payable
    {

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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
        external
        payable
    {
        fund();
    }


}