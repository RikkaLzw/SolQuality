
pragma solidity ^0.8.0;


contract PriceOracleContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    mapping(string => PriceData) private priceFeeds;
    mapping(address => bool) private authorizedOracles;
    address private owner;
    uint256 private constant PRICE_VALIDITY_DURATION = 3600;

    event PriceUpdated(string indexed symbol, uint256 price, uint256 timestamp);
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Oracle not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function updatePrice(string memory symbol, uint256 price) external onlyAuthorizedOracle {
        require(bytes(symbol).length > 0, "Invalid symbol");
        require(price > 0, "Invalid price");

        priceFeeds[symbol] = PriceData({
            price: price,
            timestamp: block.timestamp,
            isValid: true
        });

        emit PriceUpdated(symbol, price, block.timestamp);
    }

    function getPrice(string memory symbol) external view returns (uint256, uint256) {
        PriceData memory data = priceFeeds[symbol];
        require(data.isValid, "Price data not available");
        require(_isPriceValid(data.timestamp), "Price data expired");

        return (data.price, data.timestamp);
    }

    function authorizeOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(!authorizedOracles[oracle], "Oracle already authorized");

        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    function revokeOracle(address oracle) external onlyOwner {
        require(authorizedOracles[oracle], "Oracle not authorized");

        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }

    function isOracleAuthorized(address oracle) external view returns (bool) {
        return authorizedOracles[oracle];
    }

    function isPriceValid(string memory symbol) external view returns (bool) {
        PriceData memory data = priceFeeds[symbol];
        return data.isValid && _isPriceValid(data.timestamp);
    }

    function _isPriceValid(uint256 timestamp) private view returns (bool) {
        return block.timestamp <= timestamp + PRICE_VALIDITY_DURATION;
    }
}
