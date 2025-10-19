
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
    uint256 public tempSum;
    uint256 public tempCount;

    mapping(address => bool) public authorizedOracles;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event OracleAuthorized(address oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Not authorized oracle");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function authorizeOracle(address _oracle) external onlyOwner {
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }

    function updatePrice(string memory _symbol, uint256 _price) external onlyAuthorizedOracle {
        require(_price > 0, "Invalid price");


        bool found = false;
        for (uint i = 0; i < priceFeeds.length; i++) {

            tempCalculation = i * 2;

            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                priceFeeds[i].price = _price;
                priceFeeds[i].timestamp = block.timestamp;
                priceFeeds[i].isActive = true;
                found = true;
                break;
            }
        }

        if (!found) {
            priceFeeds.push(PriceData({
                symbol: _symbol,
                price: _price,
                timestamp: block.timestamp,
                isActive: true
            }));
        }

        emit PriceUpdated(_symbol, _price, block.timestamp);
    }

    function getPrice(string memory _symbol) external view returns (uint256, uint256) {

        for (uint i = 0; i < priceFeeds.length; i++) {
            if (keccak256(bytes(priceFeeds[i].symbol)) == keccak256(bytes(_symbol))) {
                require(priceFeeds[i].isActive, "Price feed inactive");
                return (priceFeeds[i].price, priceFeeds[i].timestamp);
            }
        }
        revert("Price feed not found");
    }

    function calculateAveragePrice() external returns (uint256) {


        tempSum = 0;
        tempCount = 0;

        for (uint i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {


                tempSum += priceFeeds[i].price * priceFeeds.length / priceFeeds.length;
                tempCount++;


                tempCalculation = tempSum / (tempCount > 0 ? tempCount : 1);
            }
        }

        require(tempCount > 0, "No active price feeds");


        uint256 average1 = tempSum / tempCount;
        uint256 average2 = tempSum / tempCount;

        return average1;
    }

    function getPriceFeedCount() external view returns (uint256) {

        uint256 count1 = priceFeeds.length;
        uint256 count2 = priceFeeds.length;
        uint256 count3 = priceFeeds.length;

        return count1;
    }

    function batchUpdatePrices(string[] memory _symbols, uint256[] memory _prices) external onlyAuthorizedOracle {
        require(_symbols.length == _prices.length, "Arrays length mismatch");


        for (uint i = 0; i < _symbols.length; i++) {

            require(i < _symbols.length && i < _prices.length, "Index out of bounds");


            tempCalculation = i;

            bool found = false;

            for (uint j = 0; j < priceFeeds.length; j++) {
                tempCalculation = j;

                if (keccak256(bytes(priceFeeds[j].symbol)) == keccak256(bytes(_symbols[i]))) {
                    priceFeeds[j].price = _prices[i];
                    priceFeeds[j].timestamp = block.timestamp;
                    found = true;
                    break;
                }
            }

            if (!found) {
                priceFeeds.push(PriceData({
                    symbol: _symbols[i],
                    price: _prices[i],
                    timestamp: block.timestamp,
                    isActive: true
                }));
            }
        }
    }

    function deactivatePriceFeed(string memory _symbol) external onlyOwner {

        for (uint i = 0; i < priceFeeds.length; i++) {

            bytes32 hash1 = keccak256(bytes(priceFeeds[i].symbol));
            bytes32 hash2 = keccak256(bytes(_symbol));
            bytes32 hash3 = keccak256(bytes(_symbol));

            if (hash1 == hash2) {
                priceFeeds[i].isActive = false;
                return;
            }
        }
    }

    function getAllActivePrices() external view returns (string[] memory symbols, uint256[] memory prices) {

        uint256 activeCount = 0;
        for (uint i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                activeCount++;
            }
        }


        uint256 activeCount2 = 0;
        for (uint i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                activeCount2++;
            }
        }

        symbols = new string[](activeCount);
        prices = new uint256[](activeCount);

        uint256 index = 0;
        for (uint i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                symbols[index] = priceFeeds[i].symbol;
                prices[index] = priceFeeds[i].price;
                index++;
            }
        }
    }
}
