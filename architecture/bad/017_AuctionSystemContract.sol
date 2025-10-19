
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    address public owner;
    uint256 public auctionCounter;

    struct Auction {
        address seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256) public pendingReturns;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);

    constructor() {
        owner = msg.sender;
        auctionCounter = 0;
    }

    function createAuction(string memory _itemName, string memory _description, uint256 _startingPrice, uint256 _duration) public {

        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        auctionCounter++;
        uint256 auctionId = auctionCounter;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice);
    }

    function placeBid(uint256 _auctionId) public payable {

        require(auctions[_auctionId].exists, "Auction does not exist");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(!auctions[_auctionId].ended, "Auction has been finalized");
        require(msg.sender != auctions[_auctionId].seller, "Seller cannot bid on own auction");


        uint256 minBidIncrement = 1000000000000000;

        if (auctions[_auctionId].currentBid == 0) {
            require(msg.value >= auctions[_auctionId].startingPrice, "Bid must be at least starting price");
        } else {
            require(msg.value >= auctions[_auctionId].currentBid + minBidIncrement, "Bid must be higher than current bid plus increment");
        }


        if (auctions[_auctionId].currentBidder != address(0)) {
            pendingReturns[auctions[_auctionId].currentBidder] += auctions[_auctionId].currentBid;
        }

        auctions[_auctionId].currentBid = msg.value;
        auctions[_auctionId].currentBidder = msg.sender;
        bids[_auctionId][msg.sender] = msg.value;

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) public {

        require(auctions[_auctionId].exists, "Auction does not exist");
        require(block.timestamp >= auctions[_auctionId].endTime, "Auction has not ended yet");
        require(!auctions[_auctionId].ended, "Auction already ended");

        auctions[_auctionId].ended = true;

        if (auctions[_auctionId].currentBidder != address(0)) {

            uint256 feeRate = 5;
            uint256 fee = (auctions[_auctionId].currentBid * feeRate) / 100;
            uint256 sellerAmount = auctions[_auctionId].currentBid - fee;

            payable(auctions[_auctionId].seller).transfer(sellerAmount);
            payable(owner).transfer(fee);

            emit AuctionEnded(_auctionId, auctions[_auctionId].currentBidder, auctions[_auctionId].currentBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getAuctionDetails(uint256 _auctionId) public view returns (
        address seller,
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended
    ) {

        require(auctions[_auctionId].exists, "Auction does not exist");

        Auction memory auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.ended
        );
    }

    function extendAuction(uint256 _auctionId, uint256 _additionalTime) public {

        require(auctions[_auctionId].exists, "Auction does not exist");
        require(msg.sender == auctions[_auctionId].seller, "Only seller can extend auction");
        require(!auctions[_auctionId].ended, "Cannot extend ended auction");
        require(block.timestamp < auctions[_auctionId].endTime, "Cannot extend expired auction");


        uint256 maxExtension = 604800;
        require(_additionalTime <= maxExtension, "Extension too long");

        auctions[_auctionId].endTime += _additionalTime;
    }

    function cancelAuction(uint256 _auctionId) public {

        require(auctions[_auctionId].exists, "Auction does not exist");
        require(msg.sender == auctions[_auctionId].seller, "Only seller can cancel auction");
        require(!auctions[_auctionId].ended, "Cannot cancel ended auction");
        require(auctions[_auctionId].currentBidder == address(0), "Cannot cancel auction with bids");

        auctions[_auctionId].ended = true;
        emit AuctionEnded(_auctionId, address(0), 0);
    }

    function emergencyEndAuction(uint256 _auctionId) public {

        require(msg.sender == owner, "Only owner can emergency end auction");
        require(auctions[_auctionId].exists, "Auction does not exist");
        require(!auctions[_auctionId].ended, "Auction already ended");

        auctions[_auctionId].ended = true;

        if (auctions[_auctionId].currentBidder != address(0)) {
            pendingReturns[auctions[_auctionId].currentBidder] += auctions[_auctionId].currentBid;
            auctions[_auctionId].currentBid = 0;
            auctions[_auctionId].currentBidder = address(0);
        }

        emit AuctionEnded(_auctionId, address(0), 0);
    }

    function updateMinBidIncrement(uint256 _newIncrement) public {

        require(msg.sender == owner, "Only owner can update settings");
        require(_newIncrement > 0, "Increment must be greater than 0");



    }

    function getActiveAuctions() public view returns (uint256[] memory) {
        uint256[] memory activeAuctions = new uint256[](auctionCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= auctionCounter; i++) {
            if (auctions[i].exists && !auctions[i].ended && block.timestamp < auctions[i].endTime) {
                activeAuctions[count] = i;
                count++;
            }
        }


        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeAuctions[i];
        }

        return result;
    }

    function getExpiredAuctions() public view returns (uint256[] memory) {
        uint256[] memory expiredAuctions = new uint256[](auctionCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= auctionCounter; i++) {
            if (auctions[i].exists && !auctions[i].ended && block.timestamp >= auctions[i].endTime) {
                expiredAuctions[count] = i;
                count++;
            }
        }


        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = expiredAuctions[i];
        }

        return result;
    }

    function transferOwnership(address _newOwner) public {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "New owner cannot be zero address");

        owner = _newOwner;
    }

    function getContractBalance() public view returns (uint256) {

        require(msg.sender == owner, "Only owner can view contract balance");

        return address(this).balance;
    }

    function withdrawFees() public {

        require(msg.sender == owner, "Only owner can withdraw fees");


        uint256 minWithdrawal = 10000000000000000;
        require(address(this).balance >= minWithdrawal, "Insufficient balance for withdrawal");

        payable(owner).transfer(address(this).balance);
    }
}
