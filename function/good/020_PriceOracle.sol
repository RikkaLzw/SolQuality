
pragma solidity ^0.8.0;

contract PriceOracle {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isActive;
    }

    mapping(string => PriceData) private priceFeeds;
    mapping(address => bool) private authorizedUpdaters;

    address private owner;
    uint256 private constant PRICE_VALIDITY_PERIOD = 3600;

    event PriceUpdated(string indexed asset, uint256 price, uint256 timestamp);
    event UpdaterAuthorized(address indexed updater);
    event UpdaterRevoked(address indexed updater);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender], "Not authorized updater");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }

    function updatePrice(string calldata asset, uint256 price) external onlyAuthorized {
        require(price > 0, "Invalid price");
        require(bytes(asset).length > 0, "Invalid asset");

        priceFeeds[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            isActive: true
        });

        emit PriceUpdated(asset, price, block.timestamp);
    }

    function getPrice(string calldata asset) external view returns (uint256) {
        PriceData memory data = priceFeeds[asset];
        require(data.isActive, "Price feed inactive");
        require(_isPriceValid(data.timestamp), "Price data stale");

        return data.price;
    }

    function getPriceWithTimestamp(string calldata asset) external view returns (uint256, uint256) {
        PriceData memory data = priceFeeds[asset];
        require(data.isActive, "Price feed inactive");

        return (data.price, data.timestamp);
    }

    function authorizeUpdater(address updater) external onlyOwner {
        require(updater != address(0), "Invalid address");

        authorizedUpdaters[updater] = true;
        emit UpdaterAuthorized(updater);
    }

    function revokeUpdater(address updater) external onlyOwner {
        require(updater != owner, "Cannot revoke owner");

        authorizedUpdaters[updater] = false;
        emit UpdaterRevoked(updater);
    }

    function deactivateFeed(string calldata asset) external onlyOwner {
        require(priceFeeds[asset].timestamp > 0, "Feed does not exist");

        priceFeeds[asset].isActive = false;
    }

    function isPriceValid(string calldata asset) external view returns (bool) {
        PriceData memory data = priceFeeds[asset];
        return data.isActive && _isPriceValid(data.timestamp);
    }

    function isAuthorizedUpdater(address updater) external view returns (bool) {
        return authorizedUpdaters[updater];
    }

    function _isPriceValid(uint256 timestamp) private view returns (bool) {
        return block.timestamp <= timestamp + PRICE_VALIDITY_PERIOD;
    }
}
