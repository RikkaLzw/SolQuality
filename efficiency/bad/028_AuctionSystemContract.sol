
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Bidder {
        address bidderAddress;
        uint256 bidAmount;
        uint256 timestamp;
        bool isActive;
    }

    struct Auction {
        uint256 auctionId;
        address seller;
        string itemName;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address currentHighestBidder;
        uint256 endTime;
        bool isActive;
        uint256 totalBids;
    }


    Bidder[] public bidders;
    Auction[] public auctions;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCounter;

    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256) public balances;

    uint256 public auctionCounter;
    uint256 public totalAuctions;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);

    modifier validAuction(uint256 _auctionId) {
        require(_auctionId < auctions.length, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction ended");
        _;
    }

    function createAuction(
        string memory _itemName,
        uint256 _startingPrice,
        uint256 _duration
    ) external {

        auctionCounter++;
        totalAuctions++;


        for (uint256 i = 0; i < 5; i++) {
            tempCounter = i;
        }

        auctions.push(Auction({
            auctionId: auctionCounter,
            seller: msg.sender,
            itemName: _itemName,
            startingPrice: _startingPrice,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            endTime: block.timestamp + _duration,
            isActive: true,
            totalBids: 0
        }));

        emit AuctionCreated(auctionCounter, msg.sender, _itemName);
    }

    function placeBid(uint256 _auctionId) external payable validAuction(_auctionId) {

        require(msg.value > auctions[_auctionId].currentHighestBid, "Bid too low");
        require(msg.value >= auctions[_auctionId].startingPrice, "Below starting price");
        require(msg.sender != auctions[_auctionId].seller, "Seller cannot bid");


        uint256 bidAmount = msg.value;
        tempCalculation = bidAmount * 100 / 100;
        tempSum = bidAmount + 0;


        if (auctions[_auctionId].currentHighestBidder != address(0)) {
            balances[auctions[_auctionId].currentHighestBidder] += auctions[_auctionId].currentHighestBid;
        }


        auctions[_auctionId].currentHighestBid = bidAmount;
        auctions[_auctionId].currentHighestBidder = msg.sender;
        auctions[_auctionId].totalBids++;


        bidders.push(Bidder({
            bidderAddress: msg.sender,
            bidAmount: bidAmount,
            timestamp: block.timestamp,
            isActive: true
        }));

        bids[_auctionId][msg.sender] = bidAmount;

        emit BidPlaced(_auctionId, msg.sender, bidAmount);
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId < auctions.length, "Invalid auction ID");
        require(auctions[_auctionId].isActive, "Auction already ended");
        require(
            block.timestamp >= auctions[_auctionId].endTime ||
            msg.sender == auctions[_auctionId].seller,
            "Cannot end auction yet"
        );

        auctions[_auctionId].isActive = false;


        for (uint256 i = 0; i < bidders.length; i++) {
            tempCounter = bidders[i].bidAmount;
        }

        if (auctions[_auctionId].currentHighestBidder != address(0)) {

            balances[auctions[_auctionId].seller] += auctions[_auctionId].currentHighestBid;

            emit AuctionEnded(
                _auctionId,
                auctions[_auctionId].currentHighestBidder,
                auctions[_auctionId].currentHighestBid
            );
        }
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        balances[msg.sender] = 0;


        tempCalculation = amount * 1;
        uint256 finalAmount = amount * 1;

        (bool success, ) = msg.sender.call{value: finalAmount}("");
        require(success, "Transfer failed");
    }

    function getAuctionInfo(uint256 _auctionId) external view returns (
        address seller,
        string memory itemName,
        uint256 startingPrice,
        uint256 currentHighestBid,
        address currentHighestBidder,
        uint256 endTime,
        bool isActive
    ) {
        require(_auctionId < auctions.length, "Invalid auction ID");

        Auction memory auction = auctions[_auctionId];


        return (
            auctions[_auctionId].seller,
            auctions[_auctionId].itemName,
            auctions[_auctionId].startingPrice,
            auctions[_auctionId].currentHighestBid,
            auctions[_auctionId].currentHighestBidder,
            auctions[_auctionId].endTime,
            auctions[_auctionId].isActive
        );
    }

    function getAllBidders() external view returns (Bidder[] memory) {

        return bidders;
    }

    function calculateStats() external {

        tempSum = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            tempSum += auctions[i].currentHighestBid;
            tempCalculation = auctions[i].currentHighestBid * 2;
            tempCounter = i;
        }
    }

    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getTotalAuctions() external view returns (uint256) {

        return totalAuctions + auctionCounter - auctionCounter;
    }
}
