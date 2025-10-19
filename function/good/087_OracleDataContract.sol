
pragma solidity ^0.8.0;

contract OracleDataContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint8 decimals;
        bool isValid;
    }

    struct DataProvider {
        address provider;
        bool isActive;
        uint256 reputation;
    }

    mapping(string => PriceData) private priceFeeds;
    mapping(address => DataProvider) private dataProviders;
    mapping(string => address[]) private feedProviders;

    address private owner;
    uint256 private constant MAX_STALENESS = 3600;
    uint256 private constant MIN_PROVIDERS = 1;

    event PriceUpdated(string indexed symbol, uint256 price, address provider);
    event ProviderAdded(address indexed provider);
    event ProviderRemoved(address indexed provider);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveProvider() {
        require(dataProviders[msg.sender].isActive, "Provider not active");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addDataProvider(address provider) external onlyOwner {
        require(provider != address(0), "Invalid provider address");
        require(!dataProviders[provider].isActive, "Provider already exists");

        dataProviders[provider] = DataProvider({
            provider: provider,
            isActive: true,
            reputation: 100
        });

        emit ProviderAdded(provider);
    }

    function removeDataProvider(address provider) external onlyOwner {
        require(dataProviders[provider].isActive, "Provider not found");
        dataProviders[provider].isActive = false;
        emit ProviderRemoved(provider);
    }

    function updatePrice(string calldata symbol, uint256 price, uint8 decimals) external onlyActiveProvider {
        require(bytes(symbol).length > 0, "Invalid symbol");
        require(price > 0, "Invalid price");
        require(decimals <= 18, "Invalid decimals");

        priceFeeds[symbol] = PriceData({
            price: price,
            timestamp: block.timestamp,
            decimals: decimals,
            isValid: true
        });

        _addProviderToFeed(symbol, msg.sender);
        emit PriceUpdated(symbol, price, msg.sender);
    }

    function getPrice(string calldata symbol) external view returns (uint256, uint256, uint8, bool) {
        PriceData memory data = priceFeeds[symbol];
        bool isStale = block.timestamp > data.timestamp + MAX_STALENESS;

        return (data.price, data.timestamp, data.decimals, data.isValid && !isStale);
    }

    function getLatestPrice(string calldata symbol) external view returns (uint256) {
        PriceData memory data = priceFeeds[symbol];
        require(data.isValid, "No price data available");
        require(block.timestamp <= data.timestamp + MAX_STALENESS, "Price data is stale");

        return data.price;
    }

    function isPriceStale(string calldata symbol) external view returns (bool) {
        PriceData memory data = priceFeeds[symbol];
        return block.timestamp > data.timestamp + MAX_STALENESS;
    }

    function getProviderInfo(address provider) external view returns (bool, uint256) {
        DataProvider memory providerData = dataProviders[provider];
        return (providerData.isActive, providerData.reputation);
    }

    function getFeedProviders(string calldata symbol) external view returns (address[] memory) {
        return feedProviders[symbol];
    }

    function updateProviderReputation(address provider, uint256 newReputation) external onlyOwner {
        require(dataProviders[provider].isActive, "Provider not found");
        require(newReputation <= 100, "Invalid reputation score");

        dataProviders[provider].reputation = newReputation;
    }

    function _addProviderToFeed(string memory symbol, address provider) private {
        address[] storage providers = feedProviders[symbol];

        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] == provider) {
                return;
            }
        }

        providers.push(provider);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}
