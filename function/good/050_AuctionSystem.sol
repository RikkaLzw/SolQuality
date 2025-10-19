
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address payable seller;
        string itemName;
        uint256 startingBid;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    uint256 public nextAuctionId;
    uint256 private constant AUCTION_DURATION = 7 days;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName, uint256 startingBid);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event WithdrawalMade(address indexed bidder, uint256 amount);

    modifier auctionExists(uint256 auctionId) {
        require(auctions[auctionId].exists, "Auction does not exist");
        _;
    }

    modifier auctionActive(uint256 auctionId) {
        require(block.timestamp < auctions[auctionId].endTime, "Auction has ended");
        require(!auctions[auctionId].ended, "Auction already finalized");
        _;
    }

    modifier onlySeller(uint256 auctionId) {
        require(msg.sender == auctions[auctionId].seller, "Only seller can perform this action");
        _;
    }

    function createAuction(string memory itemName, uint256 startingBid) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startingBid > 0, "Starting bid must be greater than 0");

        uint256 auctionId = nextAuctionId++;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: itemName,
            startingBid: startingBid,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + AUCTION_DURATION,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, itemName, startingBid);
        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable auctionExists(auctionId) auctionActive(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
        require(msg.value >= auction.startingBid, "Bid must meet starting price");

        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) external auctionExists(auctionId) onlySeller(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            auction.seller.transfer(auction.highestBid);
            emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    function withdraw(uint256 auctionId) external auctionExists(auctionId) returns (bool) {
        uint256 amount = pendingReturns[auctionId][msg.sender];

        require(amount > 0, "No funds to withdraw");

        pendingReturns[auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit WithdrawalMade(msg.sender, amount);
        return true;
    }

    function getAuctionDetails(uint256 auctionId) external view auctionExists(auctionId) returns (
        address seller,
        string memory itemName,
        uint256 startingBid,
        uint256 highestBid
    ) {
        Auction storage auction = auctions[auctionId];
        return (auction.seller, auction.itemName, auction.startingBid, auction.highestBid);
    }

    function getAuctionStatus(uint256 auctionId) external view auctionExists(auctionId) returns (
        address highestBidder,
        uint256 endTime,
        bool ended,
        bool isActive
    ) {
        Auction storage auction = auctions[auctionId];
        bool active = block.timestamp < auction.endTime && !auction.ended;
        return (auction.highestBidder, auction.endTime, auction.ended, active);
    }

    function getPendingReturn(uint256 auctionId, address bidder) external view returns (uint256) {
        return pendingReturns[auctionId][bidder];
    }

    function getTotalAuctions() external view returns (uint256) {
        return nextAuctionId;
    }
}
