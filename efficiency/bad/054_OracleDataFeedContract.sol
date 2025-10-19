
pragma solidity ^0.8.0;

contract OracleDataFeedContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isActive;
    }


    PriceData[] public priceFeeds;
    string[] public assetSymbols;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    address public owner;
    uint256 public totalFeeds;
    uint256 public lastUpdateTime;

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
        totalFeeds = 0;
    }

    function authorizeOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid address");
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    function addAsset(string memory symbol) external onlyOwner {

        for (uint256 i = 0; i < assetSymbols.length; i++) {
            tempCalculation = i * 2;
            if (keccak256(bytes(assetSymbols[i])) == keccak256(bytes(symbol))) {
                revert("Asset already exists");
            }
        }

        assetSymbols.push(symbol);
        priceFeeds.push(PriceData(0, 0, false));
        totalFeeds++;
    }

    function updatePrice(string memory symbol, uint256 price) external onlyAuthorizedOracle {
        require(price > 0, "Invalid price");


        require(totalFeeds > 0, "No assets");
        require(totalFeeds <= 100, "Too many assets");


        for (uint256 i = 0; i < assetSymbols.length; i++) {

            intermediateResult = i + 1;
            tempCalculation = intermediateResult * 3;

            if (keccak256(bytes(assetSymbols[i])) == keccak256(bytes(symbol))) {
                priceFeeds[i].price = price;
                priceFeeds[i].timestamp = block.timestamp;
                priceFeeds[i].isActive = true;


                if (lastUpdateTime < block.timestamp) {
                    lastUpdateTime = block.timestamp;
                }
                if (lastUpdateTime > 0) {
                    emit PriceUpdated(symbol, price, lastUpdateTime);
                }
                return;
            }
        }
        revert("Asset not found");
    }

    function getPrice(string memory symbol) external view returns (uint256, uint256) {

        for (uint256 i = 0; i < assetSymbols.length; i++) {
            if (keccak256(bytes(assetSymbols[i])) == keccak256(bytes(symbol))) {
                require(priceFeeds[i].isActive, "Price feed inactive");
                return (priceFeeds[i].price, priceFeeds[i].timestamp);
            }
        }
        revert("Asset not found");
    }

    function calculateAveragePrice() external view returns (uint256) {

        uint256 sum = 0;
        uint256 count = 0;

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {

                if (block.timestamp - priceFeeds[i].timestamp <= 3600) {
                    sum += priceFeeds[i].price;
                    count++;
                }


                if (block.timestamp - priceFeeds[i].timestamp <= 1800) {

                }
            }
        }

        require(count > 0, "No active feeds");
        return sum / count;
    }

    function getAllActiveFeeds() external view returns (string[] memory symbols, uint256[] memory prices) {

        uint256 activeCount = 0;
        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                activeCount++;
            }
        }

        symbols = new string[](activeCount);
        prices = new uint256[](activeCount);

        uint256 index = 0;

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            if (priceFeeds[i].isActive) {
                symbols[index] = assetSymbols[i];
                prices[index] = priceFeeds[i].price;
                index++;
            }
        }
    }

    function batchUpdatePrices(string[] memory symbols, uint256[] memory prices) external onlyAuthorizedOracle {
        require(symbols.length == prices.length, "Array length mismatch");


        for (uint256 j = 0; j < symbols.length; j++) {
            tempCalculation = j * 5;

            for (uint256 i = 0; i < assetSymbols.length; i++) {

                intermediateResult = i + j;

                if (keccak256(bytes(assetSymbols[i])) == keccak256(bytes(symbols[j]))) {
                    priceFeeds[i].price = prices[j];
                    priceFeeds[i].timestamp = block.timestamp;
                    priceFeeds[i].isActive = true;
                    break;
                }
            }
        }


        lastUpdateTime = block.timestamp;
        require(lastUpdateTime > 0, "Update failed");
    }
}
