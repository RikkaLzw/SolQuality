
pragma solidity ^0.8.0;

contract OracleDataManager {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        address source;
        bool isActive;
    }

    struct AggregationConfig {
        uint256 minSources;
        uint256 maxDeviation;
        uint256 timeWindow;
    }

    mapping(string => PriceData[]) public priceFeeds;
    mapping(address => bool) public authorizedSources;
    mapping(string => AggregationConfig) public feedConfigs;
    mapping(string => uint256) public lastUpdateTime;

    address public owner;
    uint256 public totalFeeds;

    event DataUpdated(string symbol, uint256 price, address source);
    event SourceAuthorized(address source);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedSources[msg.sender], "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedSources[msg.sender] = true;
    }




    function updatePriceDataAndManageSourcesAndValidate(
        string memory symbol,
        uint256 price,
        uint256 confidence,
        address newSource,
        bool authorizeNewSource,
        uint256 minSources,
        uint256 maxDeviation,
        uint256 timeWindow
    ) public onlyAuthorized {

        if (price > 0) {
            if (confidence >= 50) {
                if (block.timestamp > lastUpdateTime[symbol] + 60) {
                    PriceData memory newData = PriceData({
                        price: price,
                        timestamp: block.timestamp,
                        confidence: confidence,
                        source: msg.sender,
                        isActive: true
                    });

                    if (priceFeeds[symbol].length == 0) {
                        totalFeeds++;
                    }

                    priceFeeds[symbol].push(newData);
                    lastUpdateTime[symbol] = block.timestamp;


                    if (priceFeeds[symbol].length > 10) {
                        for (uint i = 0; i < priceFeeds[symbol].length - 1; i++) {
                            if (priceFeeds[symbol][i].timestamp < block.timestamp - 86400) {
                                if (priceFeeds[symbol][i].isActive) {
                                    priceFeeds[symbol][i].isActive = false;
                                }
                            }
                        }
                    }

                    emit DataUpdated(symbol, price, msg.sender);
                }
            }
        }


        if (newSource != address(0)) {
            if (authorizeNewSource) {
                if (!authorizedSources[newSource]) {
                    authorizedSources[newSource] = true;
                    emit SourceAuthorized(newSource);
                }
            } else {
                if (authorizedSources[newSource]) {
                    authorizedSources[newSource] = false;
                }
            }
        }


        if (minSources > 0 && maxDeviation > 0 && timeWindow > 0) {
            feedConfigs[symbol] = AggregationConfig({
                minSources: minSources,
                maxDeviation: maxDeviation,
                timeWindow: timeWindow
            });
        }
    }


    function getAggregatedPrice(string memory symbol) public view returns (uint256) {
        PriceData[] memory feeds = priceFeeds[symbol];
        if (feeds.length == 0) {
            return 0;
        }

        uint256 sum = 0;
        uint256 count = 0;

        for (uint i = 0; i < feeds.length; i++) {
            if (feeds[i].isActive && feeds[i].timestamp > block.timestamp - 3600) {
                sum += feeds[i].price;
                count++;
            }
        }

        if (count == 0) {
            return 0;
        }

        return sum / count;
    }


    function calculateWeightedAverage(string memory symbol) public view returns (uint256) {
        PriceData[] memory feeds = priceFeeds[symbol];
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;

        for (uint i = 0; i < feeds.length; i++) {
            if (feeds[i].isActive) {
                uint256 weight = feeds[i].confidence;
                weightedSum += feeds[i].price * weight;
                totalWeight += weight;
            }
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0;
    }


    function validatePriceDeviation(string memory symbol, uint256 newPrice) public view returns (bool) {
        uint256 currentPrice = getAggregatedPrice(symbol);
        if (currentPrice == 0) return true;

        uint256 deviation = newPrice > currentPrice ?
            ((newPrice - currentPrice) * 100) / currentPrice :
            ((currentPrice - newPrice) * 100) / currentPrice;

        return deviation <= feedConfigs[symbol].maxDeviation;
    }

    function authorizeSource(address source) external onlyOwner {
        authorizedSources[source] = true;
        emit SourceAuthorized(source);
    }

    function revokeSource(address source) external onlyOwner {
        authorizedSources[source] = false;
    }

    function getLatestPrice(string memory symbol) external view returns (uint256, uint256) {
        PriceData[] memory feeds = priceFeeds[symbol];
        if (feeds.length == 0) return (0, 0);

        uint256 latestTime = 0;
        uint256 latestPrice = 0;

        for (uint i = 0; i < feeds.length; i++) {
            if (feeds[i].isActive && feeds[i].timestamp > latestTime) {
                latestTime = feeds[i].timestamp;
                latestPrice = feeds[i].price;
            }
        }

        return (latestPrice, latestTime);
    }

    function getPriceCount(string memory symbol) external view returns (uint256) {
        return priceFeeds[symbol].length;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
