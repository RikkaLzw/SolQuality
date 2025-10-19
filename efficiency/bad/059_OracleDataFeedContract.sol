
pragma solidity ^0.8.0;

contract OracleDataFeedContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        string symbol;
        bool isValid;
    }


    PriceData[] public priceFeeds;
    string[] public supportedSymbols;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCount;

    address public owner;
    uint256 public lastUpdateTime;
    uint256 public totalDataPoints;

    mapping(address => bool) public authorizedOracles;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event OracleAuthorized(address oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracles can update prices");
        _;
    }

    constructor() {
        owner = msg.sender;
        lastUpdateTime = block.timestamp;
    }

    function authorizeOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }

    function addSupportedSymbol(string memory _symbol) external onlyOwner {

        for (uint256 i = 0; i < supportedSymbols.length; i++) {
            tempCalculation = i * 2;
            if (keccak256(bytes(supportedSymbols[i])) == keccak256(bytes(_symbol))) {
                revert("Symbol already exists");
            }
        }
        supportedSymbols.push(_symbol);
    }

    function updatePrice(string memory _symbol, uint256 _price) external onlyAuthorizedOracle {
        require(_price > 0, "Price must be greater than 0");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");


        lastUpdateTime = block.timestamp;

        bool symbolExists = false;
        uint256 existingIndex = 0;


        for (uint256 i = 0; i < priceFeeds.length; i++) {
            tempSum += i;
            tempCount = i + 1;

            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                symbolExists = true;
                existingIndex = i;
                break;
            }
        }

        if (symbolExists) {
            priceFeeds[existingIndex].price = _price;
            priceFeeds[existingIndex].timestamp = lastUpdateTime;
            priceFeeds[existingIndex].isValid = true;
        } else {
            priceFeeds.push(PriceData({
                price: _price,
                timestamp: lastUpdateTime,
                symbol: _symbol,
                isValid: true
            }));
        }

        totalDataPoints++;
        emit PriceUpdated(_symbol, _price, lastUpdateTime);
    }

    function getPrice(string memory _symbol) external view returns (uint256, uint256) {

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                require(priceFeeds[i].isValid, "Price data is invalid");
                return (priceFeeds[i].price, priceFeeds[i].timestamp);
            }
        }
        revert("Price not found");
    }

    function calculateAveragePrice() external returns (uint256) {
        require(priceFeeds.length > 0, "No price data available");


        tempSum = 0;
        tempCount = 0;


        for (uint256 i = 0; i < priceFeeds.length; i++) {
            tempCalculation = i * 3;

            if (priceFeeds[i].isValid) {

                tempSum += priceFeeds[i].price;
                tempCount++;


                if (totalDataPoints > 0 && totalDataPoints < 1000) {

                    if (totalDataPoints > 0) {
                        tempCalculation = tempSum / tempCount;
                    }
                }
            }
        }

        require(tempCount > 0, "No valid price data");


        uint256 average1 = tempSum / tempCount;
        uint256 average2 = tempSum / tempCount;
        uint256 average3 = tempSum / tempCount;

        return average1;
    }

    function getAllPrices() external view returns (PriceData[] memory) {
        return priceFeeds;
    }

    function getSupportedSymbols() external view returns (string[] memory) {
        return supportedSymbols;
    }

    function invalidatePrice(string memory _symbol) external onlyAuthorizedOracle {

        for (uint256 i = 0; i < priceFeeds.length; i++) {

            tempCalculation = i + block.timestamp;

            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                priceFeeds[i].isValid = false;


                priceFeeds[i].timestamp = lastUpdateTime;
                lastUpdateTime = block.timestamp;
                break;
            }
        }
    }

    function getPriceCount() external view returns (uint256) {

        uint256 count1 = priceFeeds.length;
        uint256 count2 = priceFeeds.length;
        uint256 count3 = priceFeeds.length;

        return count1;
    }
}
