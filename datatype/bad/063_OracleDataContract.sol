
pragma solidity ^0.8.0;

contract OracleDataContract {
    address public owner;


    uint256 public dataSourceCount;
    uint256 public maxDataAge;
    uint256 public minConfidence;


    string public oracleId;
    string public networkId;


    bytes public latestDataHash;
    bytes public previousDataHash;


    uint256 public isActive;
    uint256 public isEmergencyMode;

    struct PriceData {
        uint256 price;
        uint256 timestamp;

        string assetSymbol;

        uint256 confidence;

        uint256 isValidated;
    }

    mapping(string => PriceData) public priceFeeds;
    string[] public supportedAssets;


    mapping(bytes => uint256) public dataSourceReliability;
    bytes[] public registeredSources;

    event PriceUpdated(string indexed asset, uint256 price, uint256 timestamp);
    event DataSourceAdded(bytes source, uint256 reliability);
    event EmergencyModeToggled(uint256 status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyWhenActive() {
        require(isActive == 1, "Contract is not active");
        _;
    }

    constructor() {
        owner = msg.sender;

        dataSourceCount = uint256(0);
        maxDataAge = uint256(3600);
        minConfidence = uint256(80);


        oracleId = "ORACLE_001";
        networkId = "ETH_MAINNET";


        isActive = uint256(1);
        isEmergencyMode = uint256(0);


        latestDataHash = new bytes(32);
        previousDataHash = new bytes(32);
    }

    function addDataSource(bytes memory sourceId, uint256 reliability) external onlyOwner {
        require(reliability <= 100, "Reliability must be <= 100");


        dataSourceReliability[sourceId] = uint256(reliability);
        registeredSources.push(sourceId);


        dataSourceCount = uint256(dataSourceCount + 1);

        emit DataSourceAdded(sourceId, reliability);
    }

    function updatePrice(
        string memory asset,
        uint256 price,
        uint256 confidence,
        bytes memory dataHash
    ) external onlyWhenActive {
        require(price > 0, "Price must be greater than 0");
        require(confidence >= minConfidence, "Confidence too low");
        require(confidence <= 100, "Invalid confidence value");


        require(dataSourceReliability[abi.encodePacked(msg.sender)] > 0, "Unauthorized data source");

        PriceData storage data = priceFeeds[asset];


        if (data.timestamp < block.timestamp) {
            data.price = price;
            data.timestamp = block.timestamp;
            data.assetSymbol = asset;

            data.confidence = uint256(confidence);

            data.isValidated = uint256(1);


            previousDataHash = latestDataHash;
            latestDataHash = dataHash;


            if (data.price == 0) {
                supportedAssets.push(asset);
            }

            emit PriceUpdated(asset, price, block.timestamp);
        }
    }

    function getPrice(string memory asset) external view returns (
        uint256 price,
        uint256 timestamp,
        uint256 confidence,
        uint256 isValid
    ) {
        PriceData memory data = priceFeeds[asset];
        require(data.timestamp > 0, "Asset not found");


        uint256 dataAge = block.timestamp - data.timestamp;
        uint256 isDataFresh = dataAge <= maxDataAge ? 1 : 0;

        return (
            data.price,
            data.timestamp,
            data.confidence,

            data.isValidated == 1 && isDataFresh == 1 ? 1 : 0
        );
    }

    function toggleEmergencyMode() external onlyOwner {

        isEmergencyMode = isEmergencyMode == 1 ? 0 : 1;
        emit EmergencyModeToggled(isEmergencyMode);
    }

    function setActive(uint256 status) external onlyOwner {
        require(status == 0 || status == 1, "Status must be 0 or 1");

        isActive = uint256(status);
    }

    function updateMaxDataAge(uint256 newMaxAge) external onlyOwner {
        require(newMaxAge > 0, "Max age must be greater than 0");

        maxDataAge = uint256(newMaxAge);
    }

    function getSupportedAssetsCount() external view returns (uint256) {

        return uint256(supportedAssets.length);
    }

    function getDataSourceCount() external view returns (uint256) {
        return dataSourceCount;
    }

    function isAssetSupported(string memory asset) external view returns (uint256) {

        return priceFeeds[asset].timestamp > 0 ? 1 : 0;
    }
}
