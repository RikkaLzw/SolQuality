
pragma solidity ^0.8.0;


contract PriceOracle {
    address public owner;
    mapping(address => bool) public authorizedFeeder;
    mapping(string => PriceData) public priceFeeds;
    mapping(string => bool) public supportedAssets;

    uint256 public constant MAX_PRICE_AGE = 3600;
    uint256 public constant MIN_PRICE = 1;

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 roundId;
        bool isActive;
    }


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeederAuthorized(address indexed feeder, bool indexed authorized);
    event AssetAdded(string indexed asset);
    event AssetRemoved(string indexed asset);
    event PriceUpdated(
        string indexed asset,
        uint256 indexed roundId,
        uint256 price,
        uint256 timestamp,
        address indexed feeder
    );
    event EmergencyStop(string indexed asset, address indexed caller);


    error OnlyOwner(address caller);
    error OnlyAuthorizedFeeder(address caller);
    error AssetNotSupported(string asset);
    error AssetAlreadyExists(string asset);
    error InvalidPrice(uint256 price);
    error StalePrice(uint256 timestamp, uint256 maxAge);
    error PriceDataInactive(string asset);
    error ZeroAddress();
    error EmptyAssetName();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner(msg.sender);
        }
        _;
    }

    modifier onlyAuthorizedFeeder() {
        if (!authorizedFeeder[msg.sender]) {
            revert OnlyAuthorizedFeeder(msg.sender);
        }
        _;
    }

    modifier validAsset(string memory asset) {
        if (!supportedAssets[asset]) {
            revert AssetNotSupported(asset);
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }


    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }

        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function setFeederAuthorization(address feeder, bool authorized) external onlyOwner {
        if (feeder == address(0)) {
            revert ZeroAddress();
        }

        authorizedFeeder[feeder] = authorized;
        emit FeederAuthorized(feeder, authorized);
    }


    function addSupportedAsset(string memory asset) external onlyOwner {
        if (bytes(asset).length == 0) {
            revert EmptyAssetName();
        }
        if (supportedAssets[asset]) {
            revert AssetAlreadyExists(asset);
        }

        supportedAssets[asset] = true;
        priceFeeds[asset] = PriceData({
            price: 0,
            timestamp: 0,
            roundId: 0,
            isActive: true
        });

        emit AssetAdded(asset);
    }


    function removeSupportedAsset(string memory asset) external onlyOwner validAsset(asset) {
        supportedAssets[asset] = false;
        priceFeeds[asset].isActive = false;
        emit AssetRemoved(asset);
    }


    function updatePrice(
        string memory asset,
        uint256 price,
        uint256 roundId
    ) external onlyAuthorizedFeeder validAsset(asset) {
        if (price < MIN_PRICE) {
            revert InvalidPrice(price);
        }

        PriceData storage priceData = priceFeeds[asset];
        if (!priceData.isActive) {
            revert PriceDataInactive(asset);
        }


        require(roundId > priceData.roundId, "Round ID must be greater than current");

        priceData.price = price;
        priceData.timestamp = block.timestamp;
        priceData.roundId = roundId;

        emit PriceUpdated(asset, roundId, price, block.timestamp, msg.sender);
    }


    function getLatestPrice(string memory asset)
        external
        view
        validAsset(asset)
        returns (uint256 price, uint256 timestamp, uint256 roundId)
    {
        PriceData memory priceData = priceFeeds[asset];

        if (!priceData.isActive) {
            revert PriceDataInactive(asset);
        }

        if (block.timestamp - priceData.timestamp > MAX_PRICE_AGE) {
            revert StalePrice(priceData.timestamp, MAX_PRICE_AGE);
        }

        return (priceData.price, priceData.timestamp, priceData.roundId);
    }


    function getRawPriceData(string memory asset)
        external
        view
        validAsset(asset)
        returns (PriceData memory priceData)
    {
        return priceFeeds[asset];
    }


    function isPriceFresh(string memory asset) external view validAsset(asset) returns (bool isFresh) {
        PriceData memory priceData = priceFeeds[asset];
        return priceData.isActive && (block.timestamp - priceData.timestamp <= MAX_PRICE_AGE);
    }


    function emergencyStop(string memory asset) external onlyOwner validAsset(asset) {
        priceFeeds[asset].isActive = false;
        emit EmergencyStop(asset, msg.sender);
    }


    function reactivateAsset(string memory asset) external onlyOwner validAsset(asset) {
        priceFeeds[asset].isActive = true;
    }


    function batchUpdatePrices(
        string[] memory assets,
        uint256[] memory prices,
        uint256[] memory roundIds
    ) external onlyAuthorizedFeeder {
        require(
            assets.length == prices.length && prices.length == roundIds.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < assets.length; i++) {
            if (supportedAssets[assets[i]] && priceFeeds[assets[i]].isActive) {
                if (prices[i] >= MIN_PRICE && roundIds[i] > priceFeeds[assets[i]].roundId) {
                    priceFeeds[assets[i]].price = prices[i];
                    priceFeeds[assets[i]].timestamp = block.timestamp;
                    priceFeeds[assets[i]].roundId = roundIds[i];

                    emit PriceUpdated(assets[i], roundIds[i], prices[i], block.timestamp, msg.sender);
                }
            }
        }
    }
}
