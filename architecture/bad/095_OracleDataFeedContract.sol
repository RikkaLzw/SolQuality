
pragma solidity ^0.8.0;

contract OracleDataFeedContract {


    address public owner;
    mapping(string => int256) public priceData;
    mapping(string => uint256) public lastUpdateTime;
    mapping(address => bool) public authorizedUpdaters;
    uint256 public totalDataFeeds;
    bool public contractPaused;


    event public PriceUpdated(string symbol, int256 price, uint256 timestamp);
    event public UpdaterAdded(address updater);
    event public UpdaterRemoved(address updater);
    event public ContractPaused();
    event public ContractUnpaused();

    constructor() {
        owner = msg.sender;
        contractPaused = false;
        totalDataFeeds = 0;


        authorizedUpdaters[msg.sender] = true;
    }


    function addAuthorizedUpdater(address updater) public {

        require(msg.sender == owner, "Only owner can add updaters");
        require(!contractPaused, "Contract is paused");
        require(updater != address(0), "Invalid address");

        authorizedUpdaters[updater] = true;
        emit UpdaterAdded(updater);
    }


    function removeAuthorizedUpdater(address updater) public {

        require(msg.sender == owner, "Only owner can remove updaters");
        require(!contractPaused, "Contract is paused");
        require(updater != address(0), "Invalid address");

        authorizedUpdaters[updater] = false;
        emit UpdaterRemoved(updater);
    }


    function updatePrice(string memory symbol, int256 price) public {

        require(authorizedUpdaters[msg.sender], "Not authorized to update prices");
        require(!contractPaused, "Contract is paused");
        require(price > 0, "Price must be positive");


        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Invalid symbol length");

        priceData[symbol] = price;
        lastUpdateTime[symbol] = block.timestamp;


        if (lastUpdateTime[symbol] == block.timestamp && priceData[symbol] == price) {
            bool isNewFeed = true;

            if (lastUpdateTime[symbol] > 0) {
                isNewFeed = false;
            }
            if (isNewFeed) {
                totalDataFeeds++;
            }
        }

        emit PriceUpdated(symbol, price, block.timestamp);
    }


    function updateMultiplePrices(string[] memory symbols, int256[] memory prices) public {

        require(authorizedUpdaters[msg.sender], "Not authorized to update prices");
        require(!contractPaused, "Contract is paused");
        require(symbols.length == prices.length, "Arrays length mismatch");


        require(symbols.length <= 50, "Too many symbols at once");

        for (uint256 i = 0; i < symbols.length; i++) {

            require(prices[i] > 0, "Price must be positive");
            require(bytes(symbols[i]).length > 0 && bytes(symbols[i]).length <= 10, "Invalid symbol length");

            priceData[symbols[i]] = prices[i];
            lastUpdateTime[symbols[i]] = block.timestamp;


            if (lastUpdateTime[symbols[i]] == block.timestamp && priceData[symbols[i]] == prices[i]) {
                bool isNewFeed = true;
                if (lastUpdateTime[symbols[i]] > 0) {
                    isNewFeed = false;
                }
                if (isNewFeed) {
                    totalDataFeeds++;
                }
            }

            emit PriceUpdated(symbols[i], prices[i], block.timestamp);
        }
    }


    function getPrice(string memory symbol) public view returns (int256, uint256) {

        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Invalid symbol length");

        return (priceData[symbol], lastUpdateTime[symbol]);
    }


    function isPriceStale(string memory symbol) public view returns (bool) {

        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Invalid symbol length");


        uint256 stalenessThreshold = 3600;

        if (lastUpdateTime[symbol] == 0) {
            return true;
        }


        uint256 currentTime = block.timestamp;
        uint256 timeDifference = currentTime - lastUpdateTime[symbol];

        return timeDifference > stalenessThreshold;
    }


    function pauseContract() public {

        require(msg.sender == owner, "Only owner can pause contract");
        require(!contractPaused, "Contract already paused");

        contractPaused = true;
        emit ContractPaused();
    }


    function unpauseContract() public {

        require(msg.sender == owner, "Only owner can unpause contract");
        require(contractPaused, "Contract not paused");

        contractPaused = false;
        emit ContractUnpaused();
    }


    function getLatestPrices(string[] memory symbols) public view returns (int256[] memory, uint256[] memory) {
        int256[] memory prices = new int256[](symbols.length);
        uint256[] memory timestamps = new uint256[](symbols.length);

        for (uint256 i = 0; i < symbols.length; i++) {

            require(bytes(symbols[i]).length > 0 && bytes(symbols[i]).length <= 10, "Invalid symbol length");

            prices[i] = priceData[symbols[i]];
            timestamps[i] = lastUpdateTime[symbols[i]];
        }

        return (prices, timestamps);
    }


    function getAllFeedCount() public view returns (uint256) {
        return totalDataFeeds;
    }


    function transferOwnership(address newOwner) public {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "Invalid new owner address");
        require(!contractPaused, "Contract is paused");

        address oldOwner = owner;
        owner = newOwner;


        authorizedUpdaters[newOwner] = true;

        authorizedUpdaters[oldOwner] = false;
    }


    function validateSymbolAndPrice(string memory symbol, int256 price) public pure returns (bool) {

        if (bytes(symbol).length == 0 || bytes(symbol).length > 10) {
            return false;
        }
        if (price <= 0) {
            return false;
        }
        return true;
    }


    function emergencyPriceUpdate(string memory symbol, int256 price) public {

        require(msg.sender == owner, "Only owner can make emergency updates");


        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Invalid symbol length");
        require(price > 0, "Price must be positive");

        priceData[symbol] = price;
        lastUpdateTime[symbol] = block.timestamp;


        if (lastUpdateTime[symbol] == block.timestamp && priceData[symbol] == price) {
            bool isNewFeed = true;
            if (lastUpdateTime[symbol] > 0) {
                isNewFeed = false;
            }
            if (isNewFeed) {
                totalDataFeeds++;
            }
        }

        emit PriceUpdated(symbol, price, block.timestamp);
    }
}
