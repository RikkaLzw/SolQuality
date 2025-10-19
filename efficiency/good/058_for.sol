
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract OptimizedPriceOracle is Ownable, ReentrancyGuard, Pausable {


    struct PriceData {
        uint128 price;
        uint64 timestamp;
        uint32 round;
        uint32 deviation;
    }


    struct OracleInfo {
        address oracle;
        uint32 weight;
        uint32 lastUpdate;
        bool isActive;
    }


    uint256 private constant MAX_ORACLES = 10;
    uint256 private constant STALENESS_THRESHOLD = 3600;
    uint256 private constant MAX_DEVIATION = 1000;
    uint256 private constant BASIS_POINTS = 10000;


    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(address => OracleInfo) private oracles;
    mapping(bytes32 => mapping(address => uint128)) private oraclePrices;

    address[] private oracleList;
    bytes32[] private feedList;


    uint256 private totalWeight;
    uint256 private activeOracleCount;


    event PriceUpdated(bytes32 indexed feedId, uint128 price, uint64 timestamp, uint32 round);
    event OracleAdded(address indexed oracle, uint32 weight);
    event OracleRemoved(address indexed oracle);
    event OracleWeightUpdated(address indexed oracle, uint32 oldWeight, uint32 newWeight);


    error InvalidOracle();
    error InvalidFeedId();
    error InvalidPrice();
    error InvalidWeight();
    error OracleAlreadyExists();
    error OracleNotFound();
    error PriceStale();
    error DeviationTooHigh();
    error MaxOraclesReached();

    constructor() {
        totalWeight = 0;
        activeOracleCount = 0;
    }


    function addOracle(address _oracle, uint32 _weight) external onlyOwner {
        if (_oracle == address(0) || _weight == 0 || _weight > BASIS_POINTS) {
            revert InvalidWeight();
        }
        if (oracles[_oracle].oracle != address(0)) {
            revert OracleAlreadyExists();
        }
        if (oracleList.length >= MAX_ORACLES) {
            revert MaxOraclesReached();
        }


        uint256 newTotalWeight = totalWeight + _weight;
        uint256 newActiveCount = activeOracleCount + 1;

        oracles[_oracle] = OracleInfo({
            oracle: _oracle,
            weight: _weight,
            lastUpdate: uint32(block.timestamp),
            isActive: true
        });

        oracleList.push(_oracle);
        totalWeight = newTotalWeight;
        activeOracleCount = newActiveCount;

        emit OracleAdded(_oracle, _weight);
    }


    function removeOracle(address _oracle) external onlyOwner {
        OracleInfo storage oracleInfo = oracles[_oracle];
        if (oracleInfo.oracle == address(0)) {
            revert OracleNotFound();
        }


        totalWeight -= oracleInfo.weight;
        if (oracleInfo.isActive) {
            activeOracleCount--;
        }


        uint256 length = oracleList.length;
        for (uint256 i = 0; i < length;) {
            if (oracleList[i] == _oracle) {
                oracleList[i] = oracleList[length - 1];
                oracleList.pop();
                break;
            }
            unchecked { ++i; }
        }

        delete oracles[_oracle];
        emit OracleRemoved(_oracle);
    }


    function updatePrice(
        bytes32 _feedId,
        uint128 _price,
        uint32 _round
    ) external nonReentrant whenNotPaused {
        OracleInfo storage oracleInfo = oracles[msg.sender];
        if (oracleInfo.oracle == address(0) || !oracleInfo.isActive) {
            revert InvalidOracle();
        }
        if (_price == 0) {
            revert InvalidPrice();
        }


        uint32 currentTime = uint32(block.timestamp);


        oraclePrices[_feedId][msg.sender] = _price;
        oracleInfo.lastUpdate = currentTime;


        uint256 weightedSum = 0;
        uint256 validWeight = 0;


        address[] memory cachedOracleList = oracleList;
        uint256 oracleCount = cachedOracleList.length;

        for (uint256 i = 0; i < oracleCount;) {
            address oracle = cachedOracleList[i];
            OracleInfo memory info = oracles[oracle];

            if (info.isActive && (currentTime - info.lastUpdate) <= STALENESS_THRESHOLD) {
                uint128 oraclePrice = oraclePrices[_feedId][oracle];
                if (oraclePrice > 0) {
                    weightedSum += uint256(oraclePrice) * info.weight;
                    validWeight += info.weight;
                }
            }
            unchecked { ++i; }
        }

        if (validWeight > 0) {
            uint128 aggregatedPrice = uint128(weightedSum / validWeight);


            uint32 deviation = 0;
            if (priceFeeds[_feedId].price > 0) {
                uint256 priceDiff = aggregatedPrice > priceFeeds[_feedId].price
                    ? aggregatedPrice - priceFeeds[_feedId].price
                    : priceFeeds[_feedId].price - aggregatedPrice;
                deviation = uint32((priceDiff * BASIS_POINTS) / priceFeeds[_feedId].price);

                if (deviation > MAX_DEVIATION) {
                    revert DeviationTooHigh();
                }
            }


            priceFeeds[_feedId] = PriceData({
                price: aggregatedPrice,
                timestamp: uint64(currentTime),
                round: _round,
                deviation: deviation
            });


            if (priceFeeds[_feedId].timestamp == currentTime && deviation == 0) {
                feedList.push(_feedId);
            }

            emit PriceUpdated(_feedId, aggregatedPrice, uint64(currentTime), _round);
        }
    }


    function getLatestPrice(bytes32 _feedId) external view returns (
        uint128 price,
        uint64 timestamp,
        uint32 round
    ) {
        PriceData memory data = priceFeeds[_feedId];
        if (data.timestamp == 0) {
            revert InvalidFeedId();
        }
        if (block.timestamp - data.timestamp > STALENESS_THRESHOLD) {
            revert PriceStale();
        }

        return (data.price, data.timestamp, data.round);
    }


    function getPriceWithDeviation(bytes32 _feedId) external view returns (
        uint128 price,
        uint64 timestamp,
        uint32 round,
        uint32 deviation
    ) {
        PriceData memory data = priceFeeds[_feedId];
        if (data.timestamp == 0) {
            revert InvalidFeedId();
        }

        return (data.price, data.timestamp, data.round, data.deviation);
    }


    function getBatchPrices(bytes32[] calldata _feedIds) external view returns (
        uint128[] memory prices,
        uint64[] memory timestamps
    ) {
        uint256 length = _feedIds.length;
        prices = new uint128[](length);
        timestamps = new uint64[](length);

        for (uint256 i = 0; i < length;) {
            PriceData memory data = priceFeeds[_feedIds[i]];
            prices[i] = data.price;
            timestamps[i] = data.timestamp;
            unchecked { ++i; }
        }
    }


    function getOracleInfo(address _oracle) external view returns (
        uint32 weight,
        uint32 lastUpdate,
        bool isActive
    ) {
        OracleInfo memory info = oracles[_oracle];
        return (info.weight, info.lastUpdate, info.isActive);
    }


    function getStats() external view returns (
        uint256 _totalWeight,
        uint256 _activeOracleCount,
        uint256 _feedCount
    ) {
        return (totalWeight, activeOracleCount, feedList.length);
    }


    function updateOracleWeight(address _oracle, uint32 _newWeight) external onlyOwner {
        if (_newWeight == 0 || _newWeight > BASIS_POINTS) {
            revert InvalidWeight();
        }

        OracleInfo storage oracleInfo = oracles[_oracle];
        if (oracleInfo.oracle == address(0)) {
            revert OracleNotFound();
        }

        uint32 oldWeight = oracleInfo.weight;
        totalWeight = totalWeight - oldWeight + _newWeight;
        oracleInfo.weight = _newWeight;

        emit OracleWeightUpdated(_oracle, oldWeight, _newWeight);
    }


    function toggleOracleStatus(address _oracle) external onlyOwner {
        OracleInfo storage oracleInfo = oracles[_oracle];
        if (oracleInfo.oracle == address(0)) {
            revert OracleNotFound();
        }

        if (oracleInfo.isActive) {
            activeOracleCount--;
        } else {
            activeOracleCount++;
        }

        oracleInfo.isActive = !oracleInfo.isActive;
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }
}
