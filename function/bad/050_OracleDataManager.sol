
pragma solidity ^0.8.0;

contract OracleDataManager {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        string source;
        bool isValid;
    }

    struct AggregatedData {
        uint256 averagePrice;
        uint256 medianPrice;
        uint256 maxPrice;
        uint256 minPrice;
        uint256 dataCount;
    }

    mapping(string => PriceData[]) public priceHistory;
    mapping(string => AggregatedData) public aggregatedPrices;
    mapping(address => bool) public authorizedOracles;
    mapping(string => uint256) public lastUpdateTime;

    address public owner;
    uint256 public constant MAX_PRICE_AGE = 3600;

    event PriceUpdated(string symbol, uint256 price, string source);
    event DataProcessed(string symbol, uint256 count);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedOracles[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }




    function processComplexOracleOperation(
        string memory symbol,
        uint256 newPrice,
        string memory source,
        bool shouldAggregate,
        bool shouldValidate,
        uint256 customTimestamp,
        string memory additionalMetadata
    ) public onlyAuthorized returns (bool, uint256, string memory) {


        if (shouldValidate) {
            if (newPrice > 0) {
                if (bytes(symbol).length > 0) {
                    if (bytes(source).length > 0) {
                        if (customTimestamp > 0) {

                            PriceData memory newData = PriceData({
                                price: newPrice,
                                timestamp: customTimestamp > 0 ? customTimestamp : block.timestamp,
                                source: source,
                                isValid: true
                            });
                            priceHistory[symbol].push(newData);
                            lastUpdateTime[symbol] = block.timestamp;


                            if (shouldAggregate) {
                                if (priceHistory[symbol].length >= 3) {
                                    uint256[] memory validPrices = new uint256[](priceHistory[symbol].length);
                                    uint256 validCount = 0;
                                    uint256 sum = 0;
                                    uint256 maxPrice = 0;
                                    uint256 minPrice = type(uint256).max;

                                    for (uint256 i = 0; i < priceHistory[symbol].length; i++) {
                                        if (priceHistory[symbol][i].isValid) {
                                            if (block.timestamp - priceHistory[symbol][i].timestamp <= MAX_PRICE_AGE) {
                                                validPrices[validCount] = priceHistory[symbol][i].price;
                                                sum += priceHistory[symbol][i].price;
                                                validCount++;

                                                if (priceHistory[symbol][i].price > maxPrice) {
                                                    maxPrice = priceHistory[symbol][i].price;
                                                }
                                                if (priceHistory[symbol][i].price < minPrice) {
                                                    minPrice = priceHistory[symbol][i].price;
                                                }
                                            }
                                        }
                                    }

                                    if (validCount > 0) {

                                        uint256 medianPrice = 0;
                                        if (validCount > 1) {

                                            for (uint256 i = 0; i < validCount - 1; i++) {
                                                for (uint256 j = 0; j < validCount - i - 1; j++) {
                                                    if (validPrices[j] > validPrices[j + 1]) {
                                                        uint256 temp = validPrices[j];
                                                        validPrices[j] = validPrices[j + 1];
                                                        validPrices[j + 1] = temp;
                                                    }
                                                }
                                            }

                                            if (validCount % 2 == 0) {
                                                medianPrice = (validPrices[validCount / 2 - 1] + validPrices[validCount / 2]) / 2;
                                            } else {
                                                medianPrice = validPrices[validCount / 2];
                                            }
                                        } else {
                                            medianPrice = validPrices[0];
                                        }

                                        aggregatedPrices[symbol] = AggregatedData({
                                            averagePrice: sum / validCount,
                                            medianPrice: medianPrice,
                                            maxPrice: maxPrice,
                                            minPrice: minPrice,
                                            dataCount: validCount
                                        });
                                    }
                                }
                            }


                            emit PriceUpdated(symbol, newPrice, source);
                            if (shouldAggregate) {
                                emit DataProcessed(symbol, priceHistory[symbol].length);
                            }


                            return (true, newPrice, additionalMetadata);
                        }
                    }
                }
            }
        }

        return (false, 0, "");
    }


    function calculatePriceDeviation(string memory symbol) public view returns (uint256) {
        if (priceHistory[symbol].length < 2) {
            return 0;
        }

        uint256 latest = priceHistory[symbol][priceHistory[symbol].length - 1].price;
        uint256 previous = priceHistory[symbol][priceHistory[symbol].length - 2].price;

        if (previous == 0) {
            return 0;
        }

        if (latest > previous) {
            return ((latest - previous) * 10000) / previous;
        } else {
            return ((previous - latest) * 10000) / previous;
        }
    }

    function addOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = true;
    }

    function removeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = false;
    }

    function getLatestPrice(string memory symbol) external view returns (uint256, uint256) {
        require(priceHistory[symbol].length > 0, "No price data");
        PriceData memory latest = priceHistory[symbol][priceHistory[symbol].length - 1];
        return (latest.price, latest.timestamp);
    }

    function getPriceHistoryLength(string memory symbol) external view returns (uint256) {
        return priceHistory[symbol].length;
    }

    function getAggregatedData(string memory symbol) external view returns (AggregatedData memory) {
        return aggregatedPrices[symbol];
    }
}
