
pragma solidity ^0.8.0;

contract OracleDataFeedContract {

    address public owner;
    mapping(string => uint256) public priceData;
    mapping(string => uint256) public lastUpdateTime;
    mapping(address => bool) public authorizedOracles;
    mapping(string => bool) public supportedAssets;
    uint256 public totalUpdates;
    bool public contractActive;


    uint256 internal maxPriceAge = 3600;
    uint256 internal minUpdateInterval = 300;
    uint256 internal maxOracleCount = 10;

    event PriceUpdated(string asset, uint256 price, address oracle, uint256 timestamp);
    event OracleAdded(address oracle);
    event OracleRemoved(address oracle);
    event AssetAdded(string asset);

    constructor() {
        owner = msg.sender;
        contractActive = true;

        supportedAssets["ETH"] = true;
        supportedAssets["BTC"] = true;
        supportedAssets["USDT"] = true;
        supportedAssets["USDC"] = true;
    }


    function addOracle(address _oracle) external {

        if (msg.sender != owner) {
            revert("Only owner can add oracles");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        authorizedOracles[_oracle] = true;
        emit OracleAdded(_oracle);
    }


    function removeOracle(address _oracle) external {

        if (msg.sender != owner) {
            revert("Only owner can remove oracles");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        authorizedOracles[_oracle] = false;
        emit OracleRemoved(_oracle);
    }


    function addSupportedAsset(string memory _asset) external {

        if (msg.sender != owner) {
            revert("Only owner can add assets");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        supportedAssets[_asset] = true;
        emit AssetAdded(_asset);
    }


    function updatePrice(string memory _asset, uint256 _price) external {

        if (!authorizedOracles[msg.sender]) {
            revert("Not authorized oracle");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }


        if (!supportedAssets[_asset]) {
            revert("Asset not supported");
        }


        if (block.timestamp - lastUpdateTime[_asset] < minUpdateInterval) {
            revert("Update too frequent");
        }


        if (_price == 0) {
            revert("Invalid price");
        }

        priceData[_asset] = _price;
        lastUpdateTime[_asset] = block.timestamp;
        totalUpdates++;

        emit PriceUpdated(_asset, _price, msg.sender, block.timestamp);
    }


    function batchUpdatePrices(string[] memory _assets, uint256[] memory _prices) external {

        if (!authorizedOracles[msg.sender]) {
            revert("Not authorized oracle");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        if (_assets.length != _prices.length) {
            revert("Arrays length mismatch");
        }

        for (uint256 i = 0; i < _assets.length; i++) {

            if (!supportedAssets[_assets[i]]) {
                revert("Asset not supported");
            }


            if (block.timestamp - lastUpdateTime[_assets[i]] < minUpdateInterval) {
                revert("Update too frequent");
            }


            if (_prices[i] == 0) {
                revert("Invalid price");
            }

            priceData[_assets[i]] = _prices[i];
            lastUpdateTime[_assets[i]] = block.timestamp;
            totalUpdates++;

            emit PriceUpdated(_assets[i], _prices[i], msg.sender, block.timestamp);
        }
    }


    function getPrice(string memory _asset) public view returns (uint256, uint256) {

        if (!supportedAssets[_asset]) {
            revert("Asset not supported");
        }

        uint256 price = priceData[_asset];
        uint256 updateTime = lastUpdateTime[_asset];


        if (block.timestamp - updateTime > maxPriceAge) {
            revert("Price data too old");
        }

        return (price, updateTime);
    }


    function getLatestPrice(string memory _asset) public view returns (uint256) {

        if (!supportedAssets[_asset]) {
            revert("Asset not supported");
        }

        return priceData[_asset];
    }


    function isPriceValid(string memory _asset) public view returns (bool) {

        if (!supportedAssets[_asset]) {
            return false;
        }


        if (block.timestamp - lastUpdateTime[_asset] > maxPriceAge) {
            return false;
        }

        return priceData[_asset] > 0;
    }


    function setMaxPriceAge(uint256 _maxAge) external {

        if (msg.sender != owner) {
            revert("Only owner can set max age");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        maxPriceAge = _maxAge;
    }


    function setMinUpdateInterval(uint256 _interval) external {

        if (msg.sender != owner) {
            revert("Only owner can set interval");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        minUpdateInterval = _interval;
    }


    function pauseContract() external {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }

        contractActive = false;
    }


    function resumeContract() external {

        if (msg.sender != owner) {
            revert("Only owner can resume");
        }

        contractActive = true;
    }


    function getAveragePrice(string[] memory _assets) external view returns (uint256) {
        uint256 totalPrice = 0;
        uint256 validCount = 0;

        for (uint256 i = 0; i < _assets.length; i++) {

            if (!supportedAssets[_assets[i]]) {
                continue;
            }


            if (block.timestamp - lastUpdateTime[_assets[i]] > maxPriceAge) {
                continue;
            }

            if (priceData[_assets[i]] > 0) {
                totalPrice += priceData[_assets[i]];
                validCount++;
            }
        }

        if (validCount == 0) {
            revert("No valid prices found");
        }

        return totalPrice / validCount;
    }


    function getValidPriceCount(string[] memory _assets) external view returns (uint256) {
        uint256 validCount = 0;

        for (uint256 i = 0; i < _assets.length; i++) {

            if (!supportedAssets[_assets[i]]) {
                continue;
            }


            if (block.timestamp - lastUpdateTime[_assets[i]] > maxPriceAge) {
                continue;
            }

            if (priceData[_assets[i]] > 0) {
                validCount++;
            }
        }

        return validCount;
    }


    function getAllSupportedAssets() public view returns (string[] memory) {

        string[] memory assets = new string[](4);
        assets[0] = "ETH";
        assets[1] = "BTC";
        assets[2] = "USDT";
        assets[3] = "USDC";
        return assets;
    }


    function transferOwnership(address _newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        if (_newOwner == address(0)) {
            revert("Invalid new owner");
        }

        owner = _newOwner;
    }
}
