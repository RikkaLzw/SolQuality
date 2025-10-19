
pragma solidity ^0.8.0;

contract OracleDataFeedContract {


    address public owner;
    mapping(string => uint256) public priceData;
    mapping(string => uint256) public lastUpdateTime;
    mapping(address => bool) public authorizedFeeder;
    uint256 public totalFeeds;
    bool public contractActive;


    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event FeederAdded(address feeder);
    event FeederRemoved(address feeder);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        totalFeeds = 0;
    }


    function addAuthorizedFeeder(address _feeder) public {

        require(msg.sender == owner, "Only owner can add feeders");
        require(contractActive == true, "Contract is not active");
        require(_feeder != address(0), "Invalid feeder address");

        authorizedFeeder[_feeder] = true;
        emit FeederAdded(_feeder);
    }


    function removeAuthorizedFeeder(address _feeder) public {
        require(msg.sender == owner, "Only owner can remove feeders");
        require(contractActive == true, "Contract is not active");
        require(_feeder != address(0), "Invalid feeder address");

        authorizedFeeder[_feeder] = false;
        emit FeederRemoved(_feeder);
    }


    function updatePrice(string memory _symbol, uint256 _price) public {
        require(authorizedFeeder[msg.sender] == true, "Not authorized feeder");
        require(contractActive == true, "Contract is not active");
        require(_price > 0, "Price must be greater than zero");

        require(block.timestamp >= lastUpdateTime[_symbol] + 60, "Update too frequent");

        priceData[_symbol] = _price;
        lastUpdateTime[_symbol] = block.timestamp;
        totalFeeds = totalFeeds + 1;

        emit PriceUpdated(_symbol, _price, block.timestamp);
    }


    function updateMultiplePrices(string[] memory _symbols, uint256[] memory _prices) public {
        require(authorizedFeeder[msg.sender] == true, "Not authorized feeder");
        require(contractActive == true, "Contract is not active");
        require(_symbols.length == _prices.length, "Arrays length mismatch");

        require(_symbols.length <= 10, "Too many symbols");

        for(uint256 i = 0; i < _symbols.length; i++) {
            require(_prices[i] > 0, "Price must be greater than zero");

            require(block.timestamp >= lastUpdateTime[_symbols[i]] + 60, "Update too frequent");

            priceData[_symbols[i]] = _prices[i];
            lastUpdateTime[_symbols[i]] = block.timestamp;
            totalFeeds = totalFeeds + 1;

            emit PriceUpdated(_symbols[i], _prices[i], block.timestamp);
        }
    }


    function getPrice(string memory _symbol) internal view returns (uint256) {
        return priceData[_symbol];
    }


    function getPriceData(string memory _symbol) public view returns (uint256, uint256) {
        uint256 price = priceData[_symbol];
        uint256 updateTime = lastUpdateTime[_symbol];
        return (price, updateTime);
    }


    function emergencyPause() public {
        require(msg.sender == owner, "Only owner can pause");
        require(contractActive == true, "Already paused");

        contractActive = false;
    }


    function emergencyResume() public {
        require(msg.sender == owner, "Only owner can resume");
        require(contractActive == false, "Already active");

        contractActive = true;
    }


    function transferOwnership(address _newOwner) public {
        require(msg.sender == owner, "Only owner can transfer");
        require(contractActive == true, "Contract is not active");
        require(_newOwner != address(0), "Invalid new owner");
        require(_newOwner != owner, "Same owner");

        owner = _newOwner;
    }


    function getContractStats() public view returns (uint256, bool, address) {
        return (totalFeeds, contractActive, owner);
    }


    function batchGetPrices(string[] memory _symbols) public view returns (uint256[] memory, uint256[] memory) {
        require(_symbols.length > 0, "Empty symbols array");

        require(_symbols.length <= 20, "Too many symbols requested");

        uint256[] memory prices = new uint256[](_symbols.length);
        uint256[] memory timestamps = new uint256[](_symbols.length);

        for(uint256 i = 0; i < _symbols.length; i++) {
            prices[i] = priceData[_symbols[i]];
            timestamps[i] = lastUpdateTime[_symbols[i]];
        }

        return (prices, timestamps);
    }


    function forceUpdatePrice(string memory _symbol, uint256 _price) public {
        require(msg.sender == owner, "Only owner can force update");
        require(contractActive == true, "Contract is not active");
        require(_price > 0, "Price must be greater than zero");

        priceData[_symbol] = _price;
        lastUpdateTime[_symbol] = block.timestamp;
        totalFeeds = totalFeeds + 1;

        emit PriceUpdated(_symbol, _price, block.timestamp);
    }


    function isAuthorizedFeeder(address _feeder) public view returns (bool) {
        return authorizedFeeder[_feeder];
    }


    function isPriceStale(string memory _symbol) public view returns (bool) {
        require(lastUpdateTime[_symbol] > 0, "Price never set");

        return (block.timestamp - lastUpdateTime[_symbol]) > 3600;
    }


    function resetTotalFeeds() public {
        require(msg.sender == owner, "Only owner can reset");
        require(contractActive == true, "Contract is not active");

        totalFeeds = 0;
    }
}
