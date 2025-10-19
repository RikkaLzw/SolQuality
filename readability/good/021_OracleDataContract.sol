
pragma solidity ^0.8.0;


contract OracleDataContract {

    address public owner;


    mapping(address => bool) public authorizedOracles;


    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 roundId;
        bool isValid;
    }


    mapping(string => PriceData) public priceFeeds;


    string[] public supportedAssets;


    mapping(string => bool) public assetExists;


    uint256 public constant MIN_UPDATE_INTERVAL = 60;


    uint256 public constant PRICE_VALIDITY_PERIOD = 3600;


    event PriceUpdated(
        string indexed assetSymbol,
        uint256 newPrice,
        uint256 timestamp,
        uint256 roundId,
        address updatedBy
    );

    event OracleAuthorized(address indexed oracleAddress);
    event OracleRevoked(address indexed oracleAddress);
    event AssetAdded(string indexed assetSymbol);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracle can call this function");
        _;
    }


    modifier assetMustExist(string memory assetSymbol) {
        require(assetExists[assetSymbol], "Asset does not exist");
        _;
    }


    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }


    function addAsset(string memory assetSymbol) external onlyOwner {
        require(bytes(assetSymbol).length > 0, "Asset symbol cannot be empty");
        require(!assetExists[assetSymbol], "Asset already exists");

        supportedAssets.push(assetSymbol);
        assetExists[assetSymbol] = true;


        priceFeeds[assetSymbol] = PriceData({
            price: 0,
            timestamp: 0,
            roundId: 0,
            isValid: false
        });

        emit AssetAdded(assetSymbol);
    }


    function authorizeOracle(address oracleAddress) external onlyOwner {
        require(oracleAddress != address(0), "Invalid oracle address");
        require(!authorizedOracles[oracleAddress], "Oracle already authorized");

        authorizedOracles[oracleAddress] = true;
        emit OracleAuthorized(oracleAddress);
    }


    function revokeOracle(address oracleAddress) external onlyOwner {
        require(authorizedOracles[oracleAddress], "Oracle not authorized");

        authorizedOracles[oracleAddress] = false;
        emit OracleRevoked(oracleAddress);
    }


    function updatePrice(
        string memory assetSymbol,
        uint256 newPrice,
        uint256 roundId
    ) external onlyAuthorizedOracle assetMustExist(assetSymbol) {
        require(newPrice > 0, "Price must be greater than zero");
        require(roundId > priceFeeds[assetSymbol].roundId, "Round ID must be greater than current");

        PriceData storage currentData = priceFeeds[assetSymbol];


        require(
            block.timestamp >= currentData.timestamp + MIN_UPDATE_INTERVAL,
            "Update interval too short"
        );


        currentData.price = newPrice;
        currentData.timestamp = block.timestamp;
        currentData.roundId = roundId;
        currentData.isValid = true;

        emit PriceUpdated(assetSymbol, newPrice, block.timestamp, roundId, msg.sender);
    }


    function getLatestPrice(string memory assetSymbol)
        external
        view
        assetMustExist(assetSymbol)
        returns (
            uint256 price,
            uint256 timestamp,
            uint256 roundId,
            bool isValid
        )
    {
        PriceData memory data = priceFeeds[assetSymbol];


        bool dataIsValid = data.isValid &&
                          (block.timestamp <= data.timestamp + PRICE_VALIDITY_PERIOD);

        return (data.price, data.timestamp, data.roundId, dataIsValid);
    }


    function getBatchPrices(string[] memory assetSymbols)
        external
        view
        returns (
            uint256[] memory prices,
            uint256[] memory timestamps,
            bool[] memory isValidArray
        )
    {
        uint256 length = assetSymbols.length;
        prices = new uint256[](length);
        timestamps = new uint256[](length);
        isValidArray = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            if (assetExists[assetSymbols[i]]) {
                PriceData memory data = priceFeeds[assetSymbols[i]];
                prices[i] = data.price;
                timestamps[i] = data.timestamp;
                isValidArray[i] = data.isValid &&
                                 (block.timestamp <= data.timestamp + PRICE_VALIDITY_PERIOD);
            } else {
                prices[i] = 0;
                timestamps[i] = 0;
                isValidArray[i] = false;
            }
        }

        return (prices, timestamps, isValidArray);
    }


    function getSupportedAssetsCount() external view returns (uint256) {
        return supportedAssets.length;
    }


    function getAllSupportedAssets() external view returns (string[] memory) {
        return supportedAssets;
    }


    function isPriceExpired(string memory assetSymbol)
        external
        view
        assetMustExist(assetSymbol)
        returns (bool)
    {
        PriceData memory data = priceFeeds[assetSymbol];
        return block.timestamp > data.timestamp + PRICE_VALIDITY_PERIOD;
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != owner, "New owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function emergencyPause() external onlyOwner {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            priceFeeds[supportedAssets[i]].isValid = false;
        }
    }
}
