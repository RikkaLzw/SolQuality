
pragma solidity ^0.8.0;

contract OracleDataContract {
    struct PriceData {
        uint256 price;
        uint64 timestamp;
        uint32 roundId;
        bool isValid;
    }

    struct DataFeed {
        bytes32 feedId;
        string description;
        uint8 decimals;
        bool isActive;
        address oracle;
        uint256 lastUpdated;
    }

    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(bytes32 => DataFeed) private dataFeeds;
    mapping(address => bool) public authorizedOracles;

    address public owner;
    uint32 public totalFeeds;
    uint256 public constant STALE_THRESHOLD = 3600;

    event PriceUpdated(
        bytes32 indexed feedId,
        uint256 price,
        uint64 timestamp,
        uint32 roundId
    );

    event FeedAdded(
        bytes32 indexed feedId,
        string description,
        uint8 decimals,
        address oracle
    );

    event OracleAuthorized(address indexed oracle, bool authorized);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Not authorized oracle");
        _;
    }

    modifier validFeed(bytes32 feedId) {
        require(dataFeeds[feedId].isActive, "Feed not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function addDataFeed(
        bytes32 feedId,
        string calldata description,
        uint8 decimals,
        address oracle
    ) external onlyOwner {
        require(feedId != bytes32(0), "Invalid feed ID");
        require(!dataFeeds[feedId].isActive, "Feed already exists");
        require(oracle != address(0), "Invalid oracle address");
        require(decimals <= 18, "Invalid decimals");

        dataFeeds[feedId] = DataFeed({
            feedId: feedId,
            description: description,
            decimals: decimals,
            isActive: true,
            oracle: oracle,
            lastUpdated: 0
        });

        totalFeeds++;
        emit FeedAdded(feedId, description, decimals, oracle);
    }

    function updatePrice(
        bytes32 feedId,
        uint256 price,
        uint32 roundId
    ) external onlyAuthorizedOracle validFeed(feedId) {
        require(price > 0, "Invalid price");
        require(roundId > priceFeeds[feedId].roundId, "Round ID must increase");

        uint64 currentTimestamp = uint64(block.timestamp);

        priceFeeds[feedId] = PriceData({
            price: price,
            timestamp: currentTimestamp,
            roundId: roundId,
            isValid: true
        });

        dataFeeds[feedId].lastUpdated = block.timestamp;

        emit PriceUpdated(feedId, price, currentTimestamp, roundId);
    }

    function getLatestPrice(bytes32 feedId)
        external
        view
        validFeed(feedId)
        returns (
            uint256 price,
            uint64 timestamp,
            uint32 roundId,
            bool isValid
        )
    {
        PriceData memory data = priceFeeds[feedId];
        bool isStale = block.timestamp - data.timestamp > STALE_THRESHOLD;

        return (
            data.price,
            data.timestamp,
            data.roundId,
            data.isValid && !isStale
        );
    }

    function getFeedInfo(bytes32 feedId)
        external
        view
        returns (
            string memory description,
            uint8 decimals,
            bool isActive,
            address oracle,
            uint256 lastUpdated
        )
    {
        DataFeed memory feed = dataFeeds[feedId];
        return (
            feed.description,
            feed.decimals,
            feed.isActive,
            feed.oracle,
            feed.lastUpdated
        );
    }

    function isPriceStale(bytes32 feedId) external view returns (bool) {
        return block.timestamp - priceFeeds[feedId].timestamp > STALE_THRESHOLD;
    }

    function authorizeOracle(address oracle, bool authorized) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        authorizedOracles[oracle] = authorized;
        emit OracleAuthorized(oracle, authorized);
    }

    function deactivateFeed(bytes32 feedId) external onlyOwner {
        require(dataFeeds[feedId].isActive, "Feed not active");
        dataFeeds[feedId].isActive = false;
        priceFeeds[feedId].isValid = false;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    function getMultiplePrices(bytes32[] calldata feedIds)
        external
        view
        returns (uint256[] memory prices, bool[] memory validities)
    {
        uint256 length = feedIds.length;
        prices = new uint256[](length);
        validities = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            PriceData memory data = priceFeeds[feedIds[i]];
            bool isStale = block.timestamp - data.timestamp > STALE_THRESHOLD;

            prices[i] = data.price;
            validities[i] = data.isValid && !isStale && dataFeeds[feedIds[i]].isActive;
        }
    }
}
