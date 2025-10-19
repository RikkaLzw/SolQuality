
pragma solidity ^0.8.0;

contract OracleDataManager {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isValid;
    }

    struct FeedInfo {
        string symbol;
        address feedAddress;
        uint256 decimals;
        uint256 heartbeat;
        bool isActive;
    }

    mapping(string => PriceData) public priceFeeds;
    mapping(string => FeedInfo) public feedRegistry;
    mapping(address => bool) public authorizedUpdaters;
    mapping(string => uint256[]) public priceHistory;

    address public owner;
    uint256 public totalFeeds;
    uint256 public constant MAX_PRICE_AGE = 3600;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event FeedRegistered(string symbol, address feedAddress);

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
        authorizedUpdaters[msg.sender] = true;
    }




    function updatePriceDataAndManageFeeds(
        string memory symbol,
        uint256 price,
        uint256 confidence,
        address feedAddress,
        uint256 decimals,
        uint256 heartbeat,
        bool shouldRegisterFeed,
        bool shouldUpdateHistory
    ) public onlyAuthorized {

        if (bytes(symbol).length > 0) {
            if (price > 0) {
                if (confidence >= 50) {
                    if (block.timestamp > priceFeeds[symbol].timestamp) {

                        priceFeeds[symbol] = PriceData({
                            price: price,
                            timestamp: block.timestamp,
                            confidence: confidence,
                            isValid: true
                        });

                        emit PriceUpdated(symbol, price, block.timestamp);


                        if (shouldUpdateHistory) {
                            if (priceHistory[symbol].length >= 100) {

                                for (uint i = 0; i < priceHistory[symbol].length - 1; i++) {
                                    priceHistory[symbol][i] = priceHistory[symbol][i + 1];
                                }
                                priceHistory[symbol][priceHistory[symbol].length - 1] = price;
                            } else {
                                priceHistory[symbol].push(price);
                            }
                        }
                    }
                }
            }
        }


        if (shouldRegisterFeed) {
            if (feedAddress != address(0)) {
                if (bytes(feedRegistry[symbol].symbol).length == 0) {
                    feedRegistry[symbol] = FeedInfo({
                        symbol: symbol,
                        feedAddress: feedAddress,
                        decimals: decimals,
                        heartbeat: heartbeat,
                        isActive: true
                    });
                    totalFeeds++;
                    emit FeedRegistered(symbol, feedAddress);
                }
            }
        }
    }


    function calculateMovingAverage(string memory symbol, uint256 periods) public view returns (uint256) {
        uint256[] memory history = priceHistory[symbol];
        if (history.length == 0 || periods == 0) return 0;

        uint256 sum = 0;
        uint256 count = 0;
        uint256 startIndex = history.length > periods ? history.length - periods : 0;

        for (uint256 i = startIndex; i < history.length; i++) {
            sum += history[i];
            count++;
        }

        return count > 0 ? sum / count : 0;
    }


    function getComplexPriceAnalysis(string memory symbol) public view returns (uint256) {
        PriceData memory data = priceFeeds[symbol];

        if (data.isValid) {
            if (block.timestamp - data.timestamp <= MAX_PRICE_AGE) {
                if (data.confidence >= 80) {
                    if (priceHistory[symbol].length >= 5) {
                        uint256 avg = calculateMovingAverage(symbol, 5);
                        if (avg > 0) {
                            if (data.price > avg) {
                                return data.price * 105 / 100;
                            } else {
                                return data.price * 95 / 100;
                            }
                        }
                    }
                    return data.price;
                } else if (data.confidence >= 60) {
                    return data.price * 98 / 100;
                } else {
                    return data.price * 95 / 100;
                }
            }
        }
        return 0;
    }


    function manageFeedStatusAndCleanup(
        string memory symbol,
        bool newStatus,
        bool shouldCleanHistory,
        uint256 maxHistoryAge,
        bool shouldRecalculate
    ) public onlyOwner {

        if (bytes(feedRegistry[symbol].symbol).length > 0) {
            feedRegistry[symbol].isActive = newStatus;


            if (shouldCleanHistory) {
                if (maxHistoryAge > 0) {
                    if (priceHistory[symbol].length > maxHistoryAge) {

                        uint256[] storage history = priceHistory[symbol];
                        uint256 newLength = maxHistoryAge;
                        uint256 startIndex = history.length - newLength;

                        for (uint256 i = 0; i < newLength; i++) {
                            history[i] = history[startIndex + i];
                        }


                        while (history.length > newLength) {
                            history.pop();
                        }
                    }
                }
            }


            if (shouldRecalculate && newStatus) {
                PriceData storage data = priceFeeds[symbol];
                if (data.isValid && block.timestamp - data.timestamp <= MAX_PRICE_AGE) {

                    uint256 age = block.timestamp - data.timestamp;
                    if (age < 300) {
                        data.confidence = 100;
                    } else if (age < 900) {
                        data.confidence = 90;
                    } else if (age < 1800) {
                        data.confidence = 80;
                    } else {
                        data.confidence = 70;
                    }
                }
            }
        }
    }

    function getLatestPrice(string memory symbol) public view returns (uint256, uint256, bool) {
        PriceData memory data = priceFeeds[symbol];
        bool isRecent = (block.timestamp - data.timestamp) <= MAX_PRICE_AGE;
        return (data.price, data.timestamp, data.isValid && isRecent);
    }

    function addAuthorizedUpdater(address updater) public onlyOwner {
        authorizedUpdaters[updater] = true;
    }

    function removeAuthorizedUpdater(address updater) public onlyOwner {
        authorizedUpdaters[updater] = false;
    }

    function getPriceHistoryLength(string memory symbol) public view returns (uint256) {
        return priceHistory[symbol].length;
    }

    function isFeedActive(string memory symbol) public view returns (bool) {
        return feedRegistry[symbol].isActive;
    }
}
