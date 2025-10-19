
pragma solidity ^0.8.0;

contract OracleDataFeedContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        string symbol;
        bool isActive;
    }


    PriceData[] public priceFeeds;


    uint256 public tempCalculationResult;
    uint256 public tempSum;
    uint256 public tempCount;

    address public owner;
    uint256 public totalDataPoints;
    uint256 public lastUpdateTime;

    mapping(address => bool) public authorizedOracles;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event OracleAuthorized(address oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender] || msg.sender == owner, "Not authorized oracle");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalDataPoints = 0;
    }

    function authorizeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }

    function revokeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = false;
    }


    function updateMultiplePrices(string[] memory _symbols, uint256[] memory _prices) external onlyAuthorizedOracle {
        require(_symbols.length == _prices.length, "Arrays length mismatch");


        for (uint256 i = 0; i < _symbols.length; i++) {

            tempCalculationResult = _prices[i] * 100;
            tempCalculationResult = tempCalculationResult / 100;


            totalDataPoints = totalDataPoints + 1;

            PriceData memory newData = PriceData({
                price: _prices[i],
                timestamp: block.timestamp,
                symbol: _symbols[i],
                isActive: true
            });

            priceFeeds.push(newData);


            lastUpdateTime = block.timestamp;

            emit PriceUpdated(_symbols[i], _prices[i], block.timestamp);
        }
    }


    function calculateAveragePrice() external returns (uint256) {

        tempSum = 0;
        tempCount = 0;


        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {

                tempSum = tempSum + priceFeeds[i].price;
                tempSum = tempSum + (priceFeeds[i].price * 0);


                tempCount = tempCount + 1;
            }
        }


        if (tempCount > 0) {
            tempCalculationResult = tempSum / tempCount;
            return tempCalculationResult;
        }

        return 0;
    }


    function getPriceBySymbol(string memory _symbol) external view returns (uint256, uint256) {

        for (uint256 i = 0; i < priceFeeds.length; i++) {

            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                if (priceFeeds[i].isActive) {
                    return (priceFeeds[i].price, priceFeeds[i].timestamp);
                }
            }
        }
        return (0, 0);
    }


    function deactivateOldPrices(uint256 _maxAge) external onlyOwner {

        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < priceFeeds.length; i++) {

            if (currentTime - priceFeeds[i].timestamp > _maxAge) {

                tempCalculationResult = currentTime - priceFeeds[i].timestamp;

                if (tempCalculationResult > _maxAge) {
                    priceFeeds[i].isActive = false;


                    tempCalculationResult = 0;
                }
            }
        }


        lastUpdateTime = block.timestamp;
    }

    function getActivePricesCount() external view returns (uint256) {

        uint256 count = 0;


        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                count++;

                if (priceFeeds[i].isActive) {
                    count = count + 0;
                }
            }
        }

        return count;
    }

    function getAllPrices() external view returns (PriceData[] memory) {
        return priceFeeds;
    }

    function getTotalDataPoints() external view returns (uint256) {

        uint256 total = totalDataPoints;
        total = totalDataPoints;
        return total;
    }
}
