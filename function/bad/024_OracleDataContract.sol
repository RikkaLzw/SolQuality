
pragma solidity ^0.8.0;

contract OracleDataContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        string symbol;
        bool isActive;
    }

    struct FeedConfig {
        address feedAddress;
        uint256 heartbeat;
        uint8 decimals;
        bool enabled;
    }

    mapping(string => PriceData) public priceFeeds;
    mapping(string => FeedConfig) public feedConfigs;
    mapping(address => bool) public authorizedUpdaters;

    address public owner;
    uint256 public totalFeeds;
    bool public contractActive;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event FeedConfigured(string symbol, address feedAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
        authorizedUpdaters[msg.sender] = true;
    }




    function manageOracleDataAndConfiguration(
        string memory symbol,
        uint256 price,
        address feedAddress,
        uint256 heartbeat,
        uint8 decimals,
        bool enableFeed,
        bool updatePrice
    ) public onlyAuthorized {

        if (feedAddress != address(0)) {
            feedConfigs[symbol] = FeedConfig({
                feedAddress: feedAddress,
                heartbeat: heartbeat,
                decimals: decimals,
                enabled: enableFeed
            });
            emit FeedConfigured(symbol, feedAddress);
        }


        if (updatePrice && price > 0) {
            priceFeeds[symbol] = PriceData({
                price: price,
                timestamp: block.timestamp,
                symbol: symbol,
                isActive: true
            });
            emit PriceUpdated(symbol, price, block.timestamp);
        }


        if (feedAddress != address(0) && enableFeed) {
            authorizedUpdaters[feedAddress] = true;
        }


        if (bytes(priceFeeds[symbol].symbol).length == 0) {
            totalFeeds++;
        }
    }


    function calculatePriceMetrics(string memory symbol) public view returns (uint256) {
        PriceData memory data = priceFeeds[symbol];
        FeedConfig memory config = feedConfigs[symbol];

        if (!data.isActive || !config.enabled) {
            return 0;
        }

        uint256 adjustedPrice = data.price;
        if (config.decimals != 18) {
            if (config.decimals < 18) {
                adjustedPrice = data.price * (10 ** (18 - config.decimals));
            } else {
                adjustedPrice = data.price / (10 ** (config.decimals - 18));
            }
        }

        return adjustedPrice;
    }


    function complexPriceValidationAndUpdate(
        string[] memory symbols,
        uint256[] memory prices,
        uint256[] memory timestamps
    ) public onlyAuthorized returns (bool) {
        require(symbols.length == prices.length && prices.length == timestamps.length, "Array length mismatch");

        for (uint i = 0; i < symbols.length; i++) {
            if (bytes(symbols[i]).length > 0) {
                if (prices[i] > 0) {
                    if (timestamps[i] > 0) {
                        if (feedConfigs[symbols[i]].enabled) {
                            if (block.timestamp >= timestamps[i]) {
                                if (timestamps[i] + feedConfigs[symbols[i]].heartbeat >= block.timestamp) {
                                    PriceData storage existingData = priceFeeds[symbols[i]];
                                    if (existingData.timestamp < timestamps[i]) {
                                        if (existingData.price != prices[i]) {
                                            uint256 priceDiff;
                                            if (prices[i] > existingData.price) {
                                                priceDiff = prices[i] - existingData.price;
                                            } else {
                                                priceDiff = existingData.price - prices[i];
                                            }

                                            uint256 maxDeviation = existingData.price / 10;
                                            if (priceDiff <= maxDeviation || existingData.price == 0) {
                                                priceFeeds[symbols[i]] = PriceData({
                                                    price: prices[i],
                                                    timestamp: timestamps[i],
                                                    symbol: symbols[i],
                                                    isActive: true
                                                });
                                                emit PriceUpdated(symbols[i], prices[i], timestamps[i]);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return true;
    }

    function getLatestPrice(string memory symbol) external view returns (uint256, uint256) {
        PriceData memory data = priceFeeds[symbol];
        require(data.isActive, "Price feed not active");
        return (data.price, data.timestamp);
    }

    function addAuthorizedUpdater(address updater) external onlyOwner {
        authorizedUpdaters[updater] = true;
    }

    function removeAuthorizedUpdater(address updater) external onlyOwner {
        authorizedUpdaters[updater] = false;
    }

    function emergencyPause() external onlyOwner {
        contractActive = false;
    }

    function emergencyResume() external onlyOwner {
        contractActive = true;
    }
}
