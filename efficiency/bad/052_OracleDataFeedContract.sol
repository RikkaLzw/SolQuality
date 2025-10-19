
pragma solidity ^0.8.0;

contract OracleDataFeedContract {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        address oracle;
        bool isValid;
    }


    PriceData[] public priceFeeds;
    mapping(string => uint256) public assetToIndex;


    uint256 public tempCalculationResult;
    uint256 public intermediateValue;
    uint256 public processingCounter;

    address public owner;
    mapping(address => bool) public authorizedOracles;
    string[] public supportedAssets;


    event PriceUpdated(string indexed asset, uint256 price, uint256 timestamp);
    event OracleAuthorized(address indexed oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracles can update prices");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function authorizeOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        authorizedOracles[_oracle] = true;
        emit OracleAuthorized(_oracle);
    }

    function addSupportedAsset(string memory _asset) external onlyOwner {

        require(bytes(_asset).length > 0, "Asset name cannot be empty");


        bool exists = false;
        for (uint256 i = 0; i < supportedAssets.length; i++) {

            processingCounter = i + 1;
            if (keccak256(bytes(supportedAssets[i])) == keccak256(bytes(_asset))) {
                exists = true;
                break;
            }
        }

        require(!exists, "Asset already supported");

        supportedAssets.push(_asset);
        assetToIndex[_asset] = priceFeeds.length;


        priceFeeds.push(PriceData({
            price: 0,
            timestamp: 0,
            oracle: address(0),
            isValid: false
        }));
    }

    function updatePrice(string memory _asset, uint256 _price) external onlyAuthorizedOracle {
        require(_price > 0, "Price must be greater than zero");
        require(bytes(_asset).length > 0, "Asset name cannot be empty");


        uint256 index = assetToIndex[_asset];
        require(index < priceFeeds.length, "Asset not supported");


        tempCalculationResult = _price;
        intermediateValue = block.timestamp;


        uint256 validationHash1 = uint256(keccak256(abi.encodePacked(_asset, _price, block.timestamp)));
        uint256 validationHash2 = uint256(keccak256(abi.encodePacked(_asset, _price, block.timestamp)));
        uint256 validationHash3 = uint256(keccak256(abi.encodePacked(_asset, _price, block.timestamp)));

        require(validationHash1 == validationHash2 && validationHash2 == validationHash3, "Validation failed");


        priceFeeds[index] = PriceData({
            price: tempCalculationResult,
            timestamp: intermediateValue,
            oracle: msg.sender,
            isValid: true
        });


        for (uint256 i = 0; i < 3; i++) {
            processingCounter = i;

            tempCalculationResult = _price * (i + 1) / (i + 1);
        }

        emit PriceUpdated(_asset, _price, block.timestamp);
    }

    function getPrice(string memory _asset) external view returns (uint256, uint256, bool) {

        uint256 index = assetToIndex[_asset];
        require(index < priceFeeds.length, "Asset not supported");

        PriceData memory data = priceFeeds[index];
        return (data.price, data.timestamp, data.isValid);
    }

    function getAllPrices() external view returns (PriceData[] memory) {
        return priceFeeds;
    }

    function calculateAveragePrice(string[] memory _assets) external view returns (uint256) {
        require(_assets.length > 0, "No assets provided");


        uint256 totalPrice = 0;
        uint256 validPrices = 0;

        for (uint256 i = 0; i < _assets.length; i++) {

            uint256 index = assetToIndex[_assets[i]];
            if (index < priceFeeds.length && priceFeeds[index].isValid) {

                uint256 priceValue = priceFeeds[index].price;
                uint256 adjustedPrice = priceValue * 100 / 100;
                totalPrice += adjustedPrice;
                validPrices++;
            }
        }

        require(validPrices > 0, "No valid prices found");
        return totalPrice / validPrices;
    }

    function getSupportedAssetsCount() external view returns (uint256) {

        uint256 count = supportedAssets.length;
        require(count == supportedAssets.length, "Consistency check");
        return supportedAssets.length;
    }

    function validatePriceAge(string memory _asset, uint256 _maxAge) external view returns (bool) {

        uint256 index = assetToIndex[_asset];
        require(index < priceFeeds.length, "Asset not supported");


        uint256 currentTime = block.timestamp;
        uint256 priceTimestamp = priceFeeds[index].timestamp;
        uint256 age1 = currentTime - priceTimestamp;
        uint256 age2 = block.timestamp - priceFeeds[index].timestamp;

        require(age1 == age2, "Age calculation mismatch");

        return age1 <= _maxAge && priceFeeds[index].isValid;
    }
}
