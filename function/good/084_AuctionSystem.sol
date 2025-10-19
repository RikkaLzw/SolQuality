
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address seller;
        string itemName;
        uint256 startPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;

    uint256 public nextAuctionId;
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant MAX_AUCTION_DURATION = 30 days;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event FundsWithdrawn(uint256 indexed auctionId, address indexed recipient, uint256 amount);

    modifier onlyValidAuction(uint256 auctionId) {
        require(auctions[auctionId].exists, "Auction does not exist");
        _;
    }

    modifier onlyActiveBidding(uint256 auctionId) {
        require(!auctions[auctionId].ended, "Auction has ended");
        require(block.timestamp < auctions[auctionId].endTime, "Auction time expired");
        _;
    }

    modifier onlySeller(uint256 auctionId) {
        require(msg.sender == auctions[auctionId].seller, "Only seller can perform this action");
        _;
    }

    function createAuction(string memory itemName, uint256 startPrice, uint256 duration) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startPrice > 0, "Start price must be greater than zero");
        require(duration >= MIN_AUCTION_DURATION && duration <= MAX_AUCTION_DURATION, "Invalid auction duration");

        uint256 auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: itemName,
            startPrice: startPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: endTime,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, itemName, startPrice, endTime);
        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable onlyValidAuction(auctionId) onlyActiveBidding(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid must be greater than zero");

        uint256 minBid = auction.currentBid > 0 ? auction.currentBid : auction.startPrice;
        require(msg.value > minBid, "Bid must be higher than current bid or start price");

        if (auction.currentBidder != address(0)) {
            bids[auctionId][auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.currentBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) external onlyValidAuction(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(!auction.ended, "Auction already ended");
        require(block.timestamp >= auction.endTime, "Auction time not yet expired");

        auction.ended = true;

        if (auction.currentBidder != address(0)) {
            bids[auctionId][auction.seller] += auction.currentBid;
            emit AuctionEnded(auctionId, auction.currentBidder, auction.currentBid);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    function withdrawFunds(uint256 auctionId) external onlyValidAuction(auctionId) {
        uint256 amount = bids[auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        bids[auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(auctionId, msg.sender, amount);
    }

    function getAuctionInfo(uint256 auctionId) external view onlyValidAuction(auctionId) returns (
        address seller,
        string memory itemName,
        uint256 startPrice,
        uint256 currentBid
    ) {
        Auction memory auction = auctions[auctionId];
        return (auction.seller, auction.itemName, auction.startPrice, auction.currentBid);
    }

    function getAuctionStatus(uint256 auctionId) external view onlyValidAuction(auctionId) returns (
        address currentBidder,
        uint256 endTime,
        bool ended,
        bool isActive
    ) {
        Auction memory auction = auctions[auctionId];
        bool isActive = !auction.ended && block.timestamp < auction.endTime;
        return (auction.currentBidder, auction.endTime, auction.ended, isActive);
    }

    function getPendingWithdrawal(uint256 auctionId, address user) external view returns (uint256) {
        return bids[auctionId][user];
    }

    function getTotalAuctions() external view returns (uint256) {
        return nextAuctionId;
    }
}
