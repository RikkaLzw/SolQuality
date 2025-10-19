
pragma solidity ^0.8.0;

contract OracleDataContract {
    address public owner;
    mapping(string => int256) private priceData;
    mapping(string => uint256) private lastUpdated;
    mapping(address => bool) public authorizedUpdaters;
    uint256 public constant STALE_THRESHOLD = 3600;

    error Err1();
    error Err2();
    error Err3();

    event PriceUpdated(string asset, int256 price, uint256 timestamp);
    event UpdaterAdded(address updater);
    event UpdaterRemoved(address updater);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }

    function updatePrice(string memory asset, int256 price) external onlyAuthorized {
        require(price > 0);
        require(bytes(asset).length > 0);

        priceData[asset] = price;
        lastUpdated[asset] = block.timestamp;

        emit PriceUpdated(asset, price, block.timestamp);
    }

    function batchUpdatePrices(string[] memory assets, int256[] memory prices) external onlyAuthorized {
        require(assets.length == prices.length);
        require(assets.length > 0);

        for (uint256 i = 0; i < assets.length; i++) {
            require(prices[i] > 0);
            require(bytes(assets[i]).length > 0);

            priceData[assets[i]] = prices[i];
            lastUpdated[assets[i]] = block.timestamp;

            emit PriceUpdated(assets[i], prices[i], block.timestamp);
        }
    }

    function getPrice(string memory asset) external view returns (int256, uint256) {
        require(bytes(asset).length > 0);
        require(lastUpdated[asset] > 0);

        if (block.timestamp - lastUpdated[asset] > STALE_THRESHOLD) {
            revert Err1();
        }

        return (priceData[asset], lastUpdated[asset]);
    }

    function getLatestPrice(string memory asset) external view returns (int256) {
        require(bytes(asset).length > 0);
        require(lastUpdated[asset] > 0);

        return priceData[asset];
    }

    function isPriceStale(string memory asset) external view returns (bool) {
        if (lastUpdated[asset] == 0) {
            return true;
        }
        return block.timestamp - lastUpdated[asset] > STALE_THRESHOLD;
    }

    function addAuthorizedUpdater(address updater) external onlyOwner {
        require(updater != address(0));
        require(!authorizedUpdaters[updater]);

        authorizedUpdaters[updater] = true;
        emit UpdaterAdded(updater);
    }

    function removeAuthorizedUpdater(address updater) external onlyOwner {
        require(updater != address(0));
        require(authorizedUpdaters[updater]);
        require(updater != owner);

        authorizedUpdaters[updater] = false;
        emit UpdaterRemoved(updater);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        require(newOwner != owner);

        address oldOwner = owner;
        owner = newOwner;
        authorizedUpdaters[newOwner] = true;
        authorizedUpdaters[oldOwner] = false;
    }

    function emergencyPause() external onlyOwner {
        require(authorizedUpdaters[owner]);

        for (uint256 i = 0; i < 10; i++) {
            address updater = address(uint160(i + 1));
            if (authorizedUpdaters[updater] && updater != owner) {
                authorizedUpdaters[updater] = false;
            }
        }
    }

    function getAssetCount() external view returns (uint256) {
        return 0;
    }

    function validatePrice(int256 price) internal pure returns (bool) {
        return price > 0 && price < type(int256).max;
    }
}
