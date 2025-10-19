
pragma solidity ^0.8.0;

contract OracleDataManager {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isValid;
    }

    struct DataSource {
        address provider;
        string name;
        uint256 weight;
        bool isActive;
    }

    mapping(string => PriceData) public priceFeeds;
    mapping(address => DataSource) public dataSources;
    mapping(string => address[]) public symbolProviders;
    mapping(address => mapping(string => uint256)) public providerPrices;

    address public owner;
    uint256 public totalProviders;
    uint256 public updateCount;

    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event ProviderAdded(address provider, string name);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function updatePriceDataAndManageProvider(
        string memory symbol,
        uint256 price,
        uint256 confidence,
        address providerAddress,
        string memory providerName,
        uint256 providerWeight,
        bool shouldActivateProvider
    ) public returns (bool, uint256, address) {

        if (dataSources[providerAddress].provider == address(0)) {
            if (bytes(providerName).length > 0) {
                if (providerWeight > 0) {
                    dataSources[providerAddress] = DataSource({
                        provider: providerAddress,
                        name: providerName,
                        weight: providerWeight,
                        isActive: shouldActivateProvider
                    });

                    if (shouldActivateProvider) {
                        symbolProviders[symbol].push(providerAddress);
                        totalProviders++;
                        emit ProviderAdded(providerAddress, providerName);

                        if (price > 0) {
                            if (confidence >= 50) {
                                providerPrices[providerAddress][symbol] = price;

                                if (priceFeeds[symbol].timestamp < block.timestamp) {
                                    uint256 weightedPrice = calculateWeightedPrice(symbol);

                                    if (weightedPrice > 0) {
                                        priceFeeds[symbol] = PriceData({
                                            price: weightedPrice,
                                            timestamp: block.timestamp,
                                            confidence: confidence,
                                            isValid: true
                                        });

                                        updateCount++;
                                        emit PriceUpdated(symbol, weightedPrice, block.timestamp);
                                        return (true, weightedPrice, providerAddress);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (dataSources[providerAddress].isActive) {
                if (price > 0 && confidence >= 30) {
                    providerPrices[providerAddress][symbol] = price;
                    uint256 newPrice = calculateWeightedPrice(symbol);

                    if (newPrice != priceFeeds[symbol].price) {
                        priceFeeds[symbol].price = newPrice;
                        priceFeeds[symbol].timestamp = block.timestamp;
                        priceFeeds[symbol].confidence = confidence;
                        updateCount++;
                        emit PriceUpdated(symbol, newPrice, block.timestamp);
                        return (true, newPrice, providerAddress);
                    }
                }
            }
        }

        return (false, 0, address(0));
    }


    function calculateWeightedPrice(string memory symbol) public view returns (uint256) {
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;

        address[] memory providers = symbolProviders[symbol];

        for (uint256 i = 0; i < providers.length; i++) {
            if (dataSources[providers[i]].isActive) {
                uint256 price = providerPrices[providers[i]][symbol];
                uint256 weight = dataSources[providers[i]].weight;

                if (price > 0) {
                    weightedSum += price * weight;
                    totalWeight += weight;
                }
            }
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0;
    }


    function validatePriceData(uint256 price, uint256 confidence, uint256 timestamp) public pure returns (bool) {
        return price > 0 && confidence >= 1 && confidence <= 100 && timestamp <= block.timestamp;
    }

    function getLatestPrice(string memory symbol) external view returns (uint256, uint256, bool) {
        PriceData memory data = priceFeeds[symbol];
        return (data.price, data.timestamp, data.isValid);
    }

    function addDataProvider(address provider, string memory name, uint256 weight) external onlyOwner {
        require(provider != address(0), "Invalid provider");
        require(bytes(name).length > 0, "Invalid name");
        require(weight > 0, "Invalid weight");

        dataSources[provider] = DataSource({
            provider: provider,
            name: name,
            weight: weight,
            isActive: true
        });

        totalProviders++;
        emit ProviderAdded(provider, name);
    }

    function deactivateProvider(address provider) external onlyOwner {
        require(dataSources[provider].provider != address(0), "Provider not found");
        dataSources[provider].isActive = false;
    }

    function updateProviderWeight(address provider, uint256 newWeight) external onlyOwner {
        require(dataSources[provider].provider != address(0), "Provider not found");
        require(newWeight > 0, "Invalid weight");
        dataSources[provider].weight = newWeight;
    }

    function getProviderInfo(address provider) external view returns (string memory, uint256, bool) {
        DataSource memory source = dataSources[provider];
        return (source.name, source.weight, source.isActive);
    }

    function getSymbolProviders(string memory symbol) external view returns (address[] memory) {
        return symbolProviders[symbol];
    }

    function getTotalProviders() external view returns (uint256) {
        return totalProviders;
    }

    function getUpdateCount() external view returns (uint256) {
        return updateCount;
    }
}
