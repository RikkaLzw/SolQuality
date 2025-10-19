
pragma solidity ^0.8.0;

contract OracleDataFeedContract {


    address public owner;
    mapping(string => uint256) public priceData;
    mapping(string => uint256) public lastUpdateTime;
    mapping(address => bool) public authorizedFeeder;
    uint256 public totalFeeds;



    event PriceUpdated(string symbol, uint256 price, uint256 timestamp);
    event FeederAuthorized(address feeder);
    event FeederRevoked(address feeder);

    constructor() {
        owner = msg.sender;
        totalFeeds = 0;
    }


    function addAuthorizedFeeder(address _feeder) external {

        require(msg.sender == owner, "Only owner can add feeders");
        require(_feeder != address(0), "Invalid feeder address");

        authorizedFeeder[_feeder] = true;
        emit FeederAuthorized(_feeder);
    }


    function removeAuthorizedFeeder(address _feeder) external {

        require(msg.sender == owner, "Only owner can remove feeders");
        require(_feeder != address(0), "Invalid feeder address");

        authorizedFeeder[_feeder] = false;
        emit FeederRevoked(_feeder);
    }


    function updatePrice(string memory _symbol, uint256 _price) external {

        require(authorizedFeeder[msg.sender] == true, "Not authorized feeder");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");

        require(_price > 0 && _price < 1000000000000000000, "Price out of range");

        priceData[_symbol] = _price;
        lastUpdateTime[_symbol] = block.timestamp;
        totalFeeds++;

        emit PriceUpdated(_symbol, _price, block.timestamp);
    }


    function batchUpdatePrices(string[] memory _symbols, uint256[] memory _prices) external {

        require(authorizedFeeder[msg.sender] == true, "Not authorized feeder");
        require(_symbols.length == _prices.length, "Arrays length mismatch");

        require(_symbols.length <= 50, "Too many symbols");

        for(uint256 i = 0; i < _symbols.length; i++) {
            require(bytes(_symbols[i]).length > 0, "Symbol cannot be empty");

            require(_prices[i] > 0 && _prices[i] < 1000000000000000000, "Price out of range");

            priceData[_symbols[i]] = _prices[i];
            lastUpdateTime[_symbols[i]] = block.timestamp;
            totalFeeds++;

            emit PriceUpdated(_symbols[i], _prices[i], block.timestamp);
        }
    }

    function getPrice(string memory _symbol) external view returns (uint256, uint256) {
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");
        return (priceData[_symbol], lastUpdateTime[_symbol]);
    }

    function getPrices(string[] memory _symbols) external view returns (uint256[] memory, uint256[] memory) {
        require(_symbols.length > 0, "No symbols provided");

        require(_symbols.length <= 50, "Too many symbols");

        uint256[] memory prices = new uint256[](_symbols.length);
        uint256[] memory timestamps = new uint256[](_symbols.length);

        for(uint256 i = 0; i < _symbols.length; i++) {
            require(bytes(_symbols[i]).length > 0, "Symbol cannot be empty");
            prices[i] = priceData[_symbols[i]];
            timestamps[i] = lastUpdateTime[_symbols[i]];
        }

        return (prices, timestamps);
    }


    function emergencyPause() external {

        require(msg.sender == owner, "Only owner can pause");



        totalFeeds = 0;
    }


    function transferOwnership(address _newOwner) external {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "Invalid new owner address");

        owner = _newOwner;
    }

    function isDataFresh(string memory _symbol) external view returns (bool) {
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");


        if(lastUpdateTime[_symbol] == 0) {
            return false;
        }


        return (block.timestamp - lastUpdateTime[_symbol]) <= 3600;
    }

    function getStaleData(string[] memory _symbols) external view returns (string[] memory) {
        require(_symbols.length > 0, "No symbols provided");

        require(_symbols.length <= 50, "Too many symbols");

        string[] memory staleSymbols = new string[](_symbols.length);
        uint256 staleCount = 0;

        for(uint256 i = 0; i < _symbols.length; i++) {
            require(bytes(_symbols[i]).length > 0, "Symbol cannot be empty");


            if(lastUpdateTime[_symbols[i]] == 0 || (block.timestamp - lastUpdateTime[_symbols[i]]) > 3600) {
                staleSymbols[staleCount] = _symbols[i];
                staleCount++;
            }
        }


        string[] memory result = new string[](staleCount);
        for(uint256 j = 0; j < staleCount; j++) {
            result[j] = staleSymbols[j];
        }

        return result;
    }


    function getTotalFeeds() public view returns (uint256) {
        return totalFeeds;
    }


    function isAuthorizedFeeder(address _feeder) public view returns (bool) {
        return authorizedFeeder[_feeder];
    }


    function resetFeedCounter() external {

        require(msg.sender == owner, "Only owner can reset counter");

        totalFeeds = 0;
    }
}
