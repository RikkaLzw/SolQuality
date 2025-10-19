
pragma solidity ^0.8.0;

contract OracleDataContract {
    address public owner;


    uint256 public constant MAX_DATA_SOURCES = 10;
    uint256 public dataSourceCount;
    uint256 public lastUpdateTimestamp;
    uint256 public priceDecimals;


    string public oracleId;
    string public version;


    bytes public dataHash;
    bytes public signature;


    uint256 public isActive;
    uint256 public isEmergencyMode;

    struct PriceData {

        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 isValid;
        string symbol;
        bytes metadata;
    }

    mapping(string => PriceData) public priceFeeds;
    mapping(address => uint256) public authorizedSources;

    string[] public supportedAssets;

    event PriceUpdated(string indexed symbol, uint256 price, uint256 timestamp);
    event DataSourceAdded(address indexed source, string identifier);
    event EmergencyModeToggled(uint256 status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyAuthorized() {

        require(uint256(authorizedSources[msg.sender]) == uint256(1), "Not authorized source");
        _;
    }

    modifier onlyWhenActive() {

        require(isActive == uint256(1), "Oracle is not active");
        _;
    }

    constructor(string memory _oracleId, string memory _version) {
        owner = msg.sender;
        oracleId = _oracleId;
        version = _version;
        isActive = uint256(1);
        isEmergencyMode = uint256(0);
        dataSourceCount = uint256(0);
        priceDecimals = uint256(8);
        lastUpdateTimestamp = uint256(block.timestamp);
    }

    function addDataSource(address _source, string memory _identifier) external onlyOwner {
        require(_source != address(0), "Invalid source address");
        require(dataSourceCount < MAX_DATA_SOURCES, "Too many data sources");

        authorizedSources[_source] = uint256(1);
        dataSourceCount = dataSourceCount + uint256(1);

        emit DataSourceAdded(_source, _identifier);
    }

    function removeDataSource(address _source) external onlyOwner {
        require(authorizedSources[_source] == uint256(1), "Source not found");

        authorizedSources[_source] = uint256(0);
        dataSourceCount = dataSourceCount - uint256(1);
    }

    function updatePrice(
        string memory _symbol,
        uint256 _price,
        uint256 _confidence,
        bytes memory _metadata
    ) external onlyAuthorized onlyWhenActive {
        require(_price > 0, "Invalid price");
        require(_confidence <= uint256(100), "Invalid confidence");

        PriceData storage data = priceFeeds[_symbol];
        data.price = _price;
        data.confidence = _confidence;
        data.timestamp = uint256(block.timestamp);
        data.isValid = uint256(1);
        data.symbol = _symbol;
        data.metadata = _metadata;

        lastUpdateTimestamp = uint256(block.timestamp);


        if (bytes(priceFeeds[_symbol].symbol).length == 0) {
            supportedAssets.push(_symbol);
        }

        emit PriceUpdated(_symbol, _price, block.timestamp);
    }

    function getPrice(string memory _symbol) external view returns (
        uint256 price,
        uint256 confidence,
        uint256 timestamp,
        uint256 isValid
    ) {
        PriceData memory data = priceFeeds[_symbol];
        return (data.price, data.confidence, data.timestamp, data.isValid);
    }

    function getPriceWithMetadata(string memory _symbol) external view returns (
        uint256 price,
        uint256 confidence,
        uint256 timestamp,
        uint256 isValid,
        bytes memory metadata
    ) {
        PriceData memory data = priceFeeds[_symbol];
        return (data.price, data.confidence, data.timestamp, data.isValid, data.metadata);
    }

    function setDataHash(bytes memory _hash) external onlyOwner {
        dataHash = _hash;
    }

    function setSignature(bytes memory _sig) external onlyOwner {
        signature = _sig;
    }

    function toggleEmergencyMode() external onlyOwner {
        if (isEmergencyMode == uint256(0)) {
            isEmergencyMode = uint256(1);
            isActive = uint256(0);
        } else {
            isEmergencyMode = uint256(0);
            isActive = uint256(1);
        }

        emit EmergencyModeToggled(isEmergencyMode);
    }

    function setActive(uint256 _status) external onlyOwner {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        isActive = _status;
    }

    function getSupportedAssetsCount() external view returns (uint256) {
        return uint256(supportedAssets.length);
    }

    function getSupportedAsset(uint256 _index) external view returns (string memory) {
        require(_index < uint256(supportedAssets.length), "Index out of bounds");
        return supportedAssets[_index];
    }

    function isDataSourceAuthorized(address _source) external view returns (uint256) {
        return authorizedSources[_source];
    }

    function getOracleStatus() external view returns (
        uint256 active,
        uint256 emergency,
        uint256 sourceCount,
        uint256 lastUpdate
    ) {
        return (isActive, isEmergencyMode, dataSourceCount, lastUpdateTimestamp);
    }

    function updateOracleMetadata(
        string memory _newId,
        string memory _newVersion
    ) external onlyOwner {
        oracleId = _newId;
        version = _newVersion;
    }
}
