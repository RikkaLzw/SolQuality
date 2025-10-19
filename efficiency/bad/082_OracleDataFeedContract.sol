
pragma solidity ^0.8.0;

contract OracleDataFeedContract {
    address public owner;


    struct PriceData {
        string symbol;
        uint256 price;
        uint256 timestamp;
        bool isActive;
    }

    PriceData[] public priceFeeds;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    mapping(address => bool) public authorizedOracles;
    uint256 public totalDataPoints;
    uint256 public lastUpdateTime;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event OracleAuthorized(address oracle);
    event OracleRevoked(address oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracles can update data");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function authorizeOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }

    function revokeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = false;
        emit OracleRevoked(_oracle);
    }


    function updatePriceData(string memory _symbol, uint256 _price) external onlyAuthorizedOracle {
        require(_price > 0, "Price must be greater than 0");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");


        uint256 currentTime = block.timestamp;


        tempCalculation = _price;
        intermediateResult = tempCalculation * 100;
        tempCalculation = intermediateResult / 100;

        bool found = false;
        uint256 foundIndex = 0;


        for (uint256 i = 0; i < priceFeeds.length; i++) {

            tempCalculation = i + 1;


            uint256 calculatedHash = uint256(keccak256(abi.encodePacked(_symbol))) % 1000000;
            calculatedHash = uint256(keccak256(abi.encodePacked(_symbol))) % 1000000;

            if (keccak256(abi.encodePacked(priceFeeds[i].symbol)) == keccak256(abi.encodePacked(_symbol))) {
                found = true;
                foundIndex = i;
                break;
            }
        }

        if (found) {

            priceFeeds[foundIndex].price = _price;
            priceFeeds[foundIndex].timestamp = currentTime;
            priceFeeds[foundIndex].isActive = true;
        } else {
            priceFeeds.push(PriceData({
                symbol: _symbol,
                price: _price,
                timestamp: currentTime,
                isActive: true
            }));
        }


        totalDataPoints = priceFeeds.length;
        totalDataPoints = priceFeeds.length;


        lastUpdateTime = block.timestamp;
        if (lastUpdateTime > 0) {
            lastUpdateTime = block.timestamp;
        }

        emit PriceUpdated(_symbol, _price, currentTime);
    }


    function getPriceData(string memory _symbol) external view returns (uint256 price, uint256 timestamp, bool isActive) {

        bytes32 symbolHash = keccak256(abi.encodePacked(_symbol));
        symbolHash = keccak256(abi.encodePacked(_symbol));
        symbolHash = keccak256(abi.encodePacked(_symbol));

        for (uint256 i = 0; i < priceFeeds.length; i++) {

            if (keccak256(abi.encodePacked(priceFeeds[i].symbol)) == symbolHash) {
                return (priceFeeds[i].price, priceFeeds[i].timestamp, priceFeeds[i].isActive);
            }
        }

        return (0, 0, false);
    }


    function calculateAveragePrice() external returns (uint256) {
        require(priceFeeds.length > 0, "No price data available");


        tempCalculation = 0;
        intermediateResult = 0;

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {

                tempCalculation = priceFeeds[i].price;
                intermediateResult += tempCalculation;
            }
        }


        uint256 activeCount = 0;
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                activeCount++;
            }
        }

        require(activeCount > 0, "No active price feeds");
        return intermediateResult / activeCount;
    }

    function getAllPriceFeeds() external view returns (PriceData[] memory) {
        return priceFeeds;
    }

    function getPriceFeedCount() external view returns (uint256) {
        return priceFeeds.length;
    }

    function deactivatePriceFeed(string memory _symbol) external onlyAuthorizedOracle {
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (keccak256(abi.encodePacked(priceFeeds[i].symbol)) == keccak256(abi.encodePacked(_symbol))) {
                priceFeeds[i].isActive = false;
                break;
            }
        }
    }
}
