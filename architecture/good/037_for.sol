
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PriceOracleDataContract is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 public constant MAX_PRICE_DEVIATION = 1000;
    uint256 public constant MIN_UPDATE_INTERVAL = 300;
    uint256 public constant MAX_DATA_AGE = 3600;
    uint256 public constant PRICE_PRECISION = 1e8;


    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        address oracle;
        bool isValid;
    }

    struct OracleInfo {
        address oracleAddress;
        bool isActive;
        uint256 reputation;
        uint256 lastUpdateTime;
        string dataSource;
    }

    struct AggregatedPrice {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        uint256 participantCount;
    }


    mapping(string => PriceData[]) private priceHistory;
    mapping(string => AggregatedPrice) private latestPrices;
    mapping(address => OracleInfo) private authorizedOracles;
    mapping(string => bool) private supportedAssets;

    address[] private oracleList;
    string[] private assetList;

    uint256 private minOracleCount = 3;
    uint256 private aggregationThreshold = 2;


    event PriceUpdated(
        string indexed asset,
        uint256 price,
        uint256 timestamp,
        address indexed oracle
    );

    event OracleAdded(
        address indexed oracle,
        string dataSource
    );

    event OracleRemoved(address indexed oracle);

    event AssetAdded(string indexed asset);

    event PriceAggregated(
        string indexed asset,
        uint256 aggregatedPrice,
        uint256 confidence,
        uint256 participantCount
    );


    modifier onlyAuthorizedOracle() {
        require(
            authorizedOracles[msg.sender].isActive,
            "Oracle: Not authorized"
        );
        _;
    }

    modifier validAsset(string memory _asset) {
        require(
            supportedAssets[_asset],
            "Oracle: Asset not supported"
        );
        _;
    }

    modifier validPrice(uint256 _price) {
        require(_price > 0, "Oracle: Invalid price");
        _;
    }

    modifier notTooFrequent(address _oracle) {
        require(
            block.timestamp >= authorizedOracles[_oracle].lastUpdateTime.add(MIN_UPDATE_INTERVAL),
            "Oracle: Update too frequent"
        );
        _;
    }

    modifier validConfidence(uint256 _confidence) {
        require(
            _confidence > 0 && _confidence <= 100,
            "Oracle: Invalid confidence level"
        );
        _;
    }

    constructor() {

        _addAsset("BTC/USD");
        _addAsset("ETH/USD");
        _addAsset("USDT/USD");
    }


    function addOracle(
        address _oracle,
        string memory _dataSource
    ) external onlyOwner {
        require(_oracle != address(0), "Oracle: Invalid address");
        require(!authorizedOracles[_oracle].isActive, "Oracle: Already exists");

        authorizedOracles[_oracle] = OracleInfo({
            oracleAddress: _oracle,
            isActive: true,
            reputation: 100,
            lastUpdateTime: 0,
            dataSource: _dataSource
        });

        oracleList.push(_oracle);
        emit OracleAdded(_oracle, _dataSource);
    }


    function removeOracle(address _oracle) external onlyOwner {
        require(authorizedOracles[_oracle].isActive, "Oracle: Not found");

        authorizedOracles[_oracle].isActive = false;
        _removeFromOracleList(_oracle);

        emit OracleRemoved(_oracle);
    }


    function addAsset(string memory _asset) external onlyOwner {
        _addAsset(_asset);
    }


    function submitPrice(
        string memory _asset,
        uint256 _price,
        uint256 _confidence
    )
        external
        onlyAuthorizedOracle
        validAsset(_asset)
        validPrice(_price)
        validConfidence(_confidence)
        notTooFrequent(msg.sender)
        nonReentrant
    {
        PriceData memory newPriceData = PriceData({
            price: _price,
            timestamp: block.timestamp,
            confidence: _confidence,
            oracle: msg.sender,
            isValid: true
        });

        priceHistory[_asset].push(newPriceData);
        authorizedOracles[msg.sender].lastUpdateTime = block.timestamp;


        _aggregatePrice(_asset);

        emit PriceUpdated(_asset, _price, block.timestamp, msg.sender);
    }


    function getLatestPrice(string memory _asset)
        external
        view
        validAsset(_asset)
        returns (
            uint256 price,
            uint256 timestamp,
            uint256 confidence,
            bool isValid
        )
    {
        AggregatedPrice memory latestPrice = latestPrices[_asset];
        bool dataIsValid = _isDataFresh(latestPrice.timestamp);

        return (
            latestPrice.price,
            latestPrice.timestamp,
            latestPrice.confidence,
            dataIsValid
        );
    }


    function getPriceHistory(
        string memory _asset,
        uint256 _count
    )
        external
        view
        validAsset(_asset)
        returns (PriceData[] memory)
    {
        uint256 historyLength = priceHistory[_asset].length;
        uint256 returnCount = _count > historyLength ? historyLength : _count;

        PriceData[] memory result = new PriceData[](returnCount);

        for (uint256 i = 0; i < returnCount; i++) {
            result[i] = priceHistory[_asset][historyLength - 1 - i];
        }

        return result;
    }


    function getOracleInfo(address _oracle)
        external
        view
        returns (OracleInfo memory)
    {
        return authorizedOracles[_oracle];
    }


    function getSupportedAssets() external view returns (string[] memory) {
        return assetList;
    }


    function getActiveOracles() external view returns (address[] memory) {
        uint256 activeCount = 0;


        for (uint256 i = 0; i < oracleList.length; i++) {
            if (authorizedOracles[oracleList[i]].isActive) {
                activeCount++;
            }
        }


        address[] memory activeOracles = new address[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < oracleList.length; i++) {
            if (authorizedOracles[oracleList[i]].isActive) {
                activeOracles[index] = oracleList[i];
                index++;
            }
        }

        return activeOracles;
    }


    function updateConfiguration(
        uint256 _minOracleCount,
        uint256 _aggregationThreshold
    ) external onlyOwner {
        require(_minOracleCount > 0, "Oracle: Invalid min count");
        require(_aggregationThreshold > 0, "Oracle: Invalid threshold");

        minOracleCount = _minOracleCount;
        aggregationThreshold = _aggregationThreshold;
    }


    function _addAsset(string memory _asset) internal {
        require(!supportedAssets[_asset], "Oracle: Asset already supported");

        supportedAssets[_asset] = true;
        assetList.push(_asset);

        emit AssetAdded(_asset);
    }

    function _removeFromOracleList(address _oracle) internal {
        for (uint256 i = 0; i < oracleList.length; i++) {
            if (oracleList[i] == _oracle) {
                oracleList[i] = oracleList[oracleList.length - 1];
                oracleList.pop();
                break;
            }
        }
    }

    function _aggregatePrice(string memory _asset) internal {
        PriceData[] storage history = priceHistory[_asset];
        uint256 historyLength = history.length;

        if (historyLength < aggregationThreshold) {
            return;
        }


        uint256 validPriceCount = 0;
        uint256 totalWeightedPrice = 0;
        uint256 totalWeight = 0;
        uint256 minTimestamp = block.timestamp.sub(MAX_DATA_AGE);

        for (uint256 i = historyLength; i > 0; i--) {
            PriceData storage priceData = history[i - 1];

            if (priceData.timestamp < minTimestamp) {
                break;
            }

            if (priceData.isValid) {
                uint256 weight = priceData.confidence;
                totalWeightedPrice = totalWeightedPrice.add(
                    priceData.price.mul(weight)
                );
                totalWeight = totalWeight.add(weight);
                validPriceCount++;
            }
        }

        if (validPriceCount >= aggregationThreshold) {
            uint256 aggregatedPrice = totalWeightedPrice.div(totalWeight);
            uint256 confidence = totalWeight.div(validPriceCount);

            latestPrices[_asset] = AggregatedPrice({
                price: aggregatedPrice,
                timestamp: block.timestamp,
                confidence: confidence,
                participantCount: validPriceCount
            });

            emit PriceAggregated(_asset, aggregatedPrice, confidence, validPriceCount);
        }
    }

    function _isDataFresh(uint256 _timestamp) internal view returns (bool) {
        return block.timestamp.sub(_timestamp) <= MAX_DATA_AGE;
    }


    function emergencyPause() external onlyOwner {

        for (uint256 i = 0; i < oracleList.length; i++) {
            authorizedOracles[oracleList[i]].isActive = false;
        }
    }


    function reactivateOracles() external onlyOwner {
        for (uint256 i = 0; i < oracleList.length; i++) {
            authorizedOracles[oracleList[i]].isActive = true;
        }
    }
}
