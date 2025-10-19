
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract OptimizedPriceOracle is Ownable, ReentrancyGuard, Pausable {

    struct PriceData {
        uint128 price;
        uint64 timestamp;
        uint32 roundId;
        uint32 confidence;
    }


    mapping(bytes32 => PriceData) private _priceData;


    bytes32[] private _assetKeys;
    mapping(bytes32 => uint256) private _assetIndex;


    mapping(address => bool) private _authorizedOracles;
    address[] private _oracleList;
    mapping(address => uint256) private _oracleIndex;


    mapping(bytes32 => uint256) private _priceCache;
    mapping(bytes32 => uint256) private _cacheTimestamp;
    uint256 private constant CACHE_DURATION = 300;


    uint256 private constant MAX_STALENESS = 3600;
    uint256 private constant MIN_CONFIDENCE = 9000;
    uint256 private constant CONFIDENCE_DECIMALS = 10000;


    event PriceUpdated(
        bytes32 indexed assetKey,
        uint256 indexed price,
        uint256 timestamp,
        uint32 roundId
    );

    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event AssetAdded(bytes32 indexed assetKey);
    event AssetRemoved(bytes32 indexed assetKey);


    error UnauthorizedOracle();
    error InvalidPrice();
    error StalePrice();
    error AssetNotFound();
    error AssetAlreadyExists();
    error InvalidConfidence();
    error ZeroAddress();

    modifier onlyAuthorizedOracle() {
        if (!_authorizedOracles[msg.sender]) revert UnauthorizedOracle();
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }


    function updatePrice(
        bytes32 assetKey,
        uint128 price,
        uint32 confidence
    ) external onlyAuthorizedOracle whenNotPaused nonReentrant {
        if (price == 0) revert InvalidPrice();
        if (confidence < MIN_CONFIDENCE) revert InvalidConfidence();


        PriceData storage data = _priceData[assetKey];
        if (data.timestamp == 0 && _assetIndex[assetKey] == 0 && _assetKeys.length > 0 && _assetKeys[0] != assetKey) {
            revert AssetNotFound();
        }

        uint64 currentTimestamp = uint64(block.timestamp);
        uint32 newRoundId = data.roundId + 1;


        _priceData[assetKey] = PriceData({
            price: price,
            timestamp: currentTimestamp,
            roundId: newRoundId,
            confidence: confidence
        });


        _priceCache[assetKey] = price;
        _cacheTimestamp[assetKey] = block.timestamp;

        emit PriceUpdated(assetKey, price, currentTimestamp, newRoundId);
    }


    function getLatestPrice(bytes32 assetKey)
        external
        view
        returns (uint256 price, uint256 timestamp)
    {

        uint256 cacheTime = _cacheTimestamp[assetKey];
        if (cacheTime > 0 && block.timestamp - cacheTime < CACHE_DURATION) {
            return (_priceCache[assetKey], cacheTime);
        }

        PriceData memory data = _priceData[assetKey];
        if (data.timestamp == 0) revert AssetNotFound();
        if (block.timestamp - data.timestamp > MAX_STALENESS) revert StalePrice();

        return (data.price, data.timestamp);
    }


    function getPriceData(bytes32 assetKey)
        external
        view
        returns (PriceData memory data)
    {
        data = _priceData[assetKey];
        if (data.timestamp == 0) revert AssetNotFound();
    }


    function getBatchPrices(bytes32[] calldata assetKeys)
        external
        view
        returns (uint256[] memory prices, uint256[] memory timestamps)
    {
        uint256 length = assetKeys.length;
        prices = new uint256[](length);
        timestamps = new uint256[](length);


        for (uint256 i = 0; i < length;) {
            PriceData memory data = _priceData[assetKeys[i]];
            prices[i] = data.price;
            timestamps[i] = data.timestamp;

            unchecked {
                ++i;
            }
        }
    }


    function addAsset(bytes32 assetKey) external onlyOwner {
        if (assetKey == bytes32(0)) revert InvalidPrice();


        if (_priceData[assetKey].timestamp != 0 ||
            (_assetKeys.length > 0 && _assetIndex[assetKey] != 0) ||
            (_assetKeys.length > 0 && _assetKeys[0] == assetKey)) {
            revert AssetAlreadyExists();
        }

        _assetIndex[assetKey] = _assetKeys.length;
        _assetKeys.push(assetKey);

        emit AssetAdded(assetKey);
    }


    function removeAsset(bytes32 assetKey) external onlyOwner {
        uint256 index = _assetIndex[assetKey];
        uint256 lastIndex = _assetKeys.length - 1;

        if (index > lastIndex || _assetKeys[index] != assetKey) {
            revert AssetNotFound();
        }


        if (index != lastIndex) {
            bytes32 lastAsset = _assetKeys[lastIndex];
            _assetKeys[index] = lastAsset;
            _assetIndex[lastAsset] = index;
        }

        _assetKeys.pop();
        delete _assetIndex[assetKey];
        delete _priceData[assetKey];
        delete _priceCache[assetKey];
        delete _cacheTimestamp[assetKey];

        emit AssetRemoved(assetKey);
    }


    function authorizeOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert ZeroAddress();
        if (_authorizedOracles[oracle]) return;

        _authorizedOracles[oracle] = true;
        _oracleIndex[oracle] = _oracleList.length;
        _oracleList.push(oracle);

        emit OracleAuthorized(oracle);
    }


    function revokeOracle(address oracle) external onlyOwner {
        if (!_authorizedOracles[oracle]) return;

        uint256 index = _oracleIndex[oracle];
        uint256 lastIndex = _oracleList.length - 1;


        if (index != lastIndex) {
            address lastOracle = _oracleList[lastIndex];
            _oracleList[index] = lastOracle;
            _oracleIndex[lastOracle] = index;
        }

        _oracleList.pop();
        delete _oracleIndex[oracle];
        delete _authorizedOracles[oracle];

        emit OracleRevoked(oracle);
    }


    function isAuthorizedOracle(address oracle) external view returns (bool) {
        return _authorizedOracles[oracle];
    }


    function getAllAssets() external view returns (bytes32[] memory) {
        return _assetKeys;
    }


    function getAssetCount() external view returns (uint256) {
        return _assetKeys.length;
    }


    function getAuthorizedOracles() external view returns (address[] memory) {
        return _oracleList;
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function clearCache(bytes32 assetKey) external onlyOwner {
        delete _priceCache[assetKey];
        delete _cacheTimestamp[assetKey];
    }
}
