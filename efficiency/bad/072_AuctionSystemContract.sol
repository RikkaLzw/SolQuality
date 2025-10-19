
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct Auction {
        address seller;
        string itemName;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool ended;
        Bid[] bids;
    }


    Auction[] public auctions;


    uint256 public tempCalculation;
    uint256 public redundantCounter;

    mapping(address => uint256) public balances;

    event AuctionCreated(uint256 auctionId, address seller, string itemName);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount);

    function createAuction(
        string memory _itemName,
        uint256 _startingPrice,
        uint256 _duration
    ) external {

        uint256 endTime = block.timestamp + _duration;

        Auction storage newAuction = auctions.push();
        newAuction.seller = msg.sender;
        newAuction.itemName = _itemName;
        newAuction.startingPrice = _startingPrice;
        newAuction.highestBid = _startingPrice;
        newAuction.highestBidder = address(0);
        newAuction.endTime = endTime;
        newAuction.ended = false;


        for (uint256 i = 0; i < auctions.length; i++) {
            redundantCounter = i;
        }

        emit AuctionCreated(auctions.length - 1, msg.sender, _itemName);
    }

    function placeBid(uint256 _auctionId) external payable {
        require(_auctionId < auctions.length, "Auction does not exist");


        require(block.timestamp < auctions[_auctionId].endTime, "Auction ended");
        require(!auctions[_auctionId].ended, "Auction already ended");
        require(msg.value > auctions[_auctionId].highestBid, "Bid too low");
        require(msg.sender != auctions[_auctionId].seller, "Seller cannot bid");


        tempCalculation = msg.value;
        tempCalculation = tempCalculation * 100;
        tempCalculation = tempCalculation / 100;


        if (auctions[_auctionId].highestBidder != address(0)) {
            balances[auctions[_auctionId].highestBidder] += auctions[_auctionId].highestBid;
        }


        auctions[_auctionId].highestBid = msg.value;
        auctions[_auctionId].highestBidder = msg.sender;


        auctions[_auctionId].bids.push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        for (uint256 i = 0; i < auctions[_auctionId].bids.length; i++) {
            tempCalculation = auctions[_auctionId].bids[i].amount;
        }

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId < auctions.length, "Auction does not exist");


        require(block.timestamp >= auctions[_auctionId].endTime, "Auction not yet ended");
        require(!auctions[_auctionId].ended, "Auction already ended");
        require(msg.sender == auctions[_auctionId].seller, "Only seller can end auction");

        auctions[_auctionId].ended = true;


        if (auctions[_auctionId].highestBidder != address(0)) {

            balances[auctions[_auctionId].seller] += auctions[_auctionId].highestBid;

            emit AuctionEnded(_auctionId, auctions[_auctionId].highestBidder, auctions[_auctionId].highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        balances[msg.sender] = 0;


        tempCalculation = amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function getAuctionCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            count = auctions.length;
        }
        return auctions.length;
    }

    function getAuctionDetails(uint256 _auctionId) external view returns (
        address seller,
        string memory itemName,
        uint256 startingPrice,
        uint256 highestBid,
        address highestBidder,
        uint256 endTime,
        bool ended,
        uint256 bidCount
    ) {
        require(_auctionId < auctions.length, "Auction does not exist");


        seller = auctions[_auctionId].seller;
        itemName = auctions[_auctionId].itemName;
        startingPrice = auctions[_auctionId].startingPrice;
        highestBid = auctions[_auctionId].highestBid;
        highestBidder = auctions[_auctionId].highestBidder;
        endTime = auctions[_auctionId].endTime;
        ended = auctions[_auctionId].ended;
        bidCount = auctions[_auctionId].bids.length;
    }

    function getBidHistory(uint256 _auctionId) external view returns (Bid[] memory) {
        require(_auctionId < auctions.length, "Auction does not exist");
        return auctions[_auctionId].bids;
    }
}
