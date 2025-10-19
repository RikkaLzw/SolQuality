
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address seller;
        string itemName;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionEndTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    uint256 public nextAuctionId;
    uint256 public constant AUCTION_DURATION = 7 days;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);
    event WithdrawalMade(uint256 indexed auctionId, address indexed bidder, uint256 amount);

    modifier auctionExists(uint256 auctionId) {
        require(auctions[auctionId].exists, "Auction does not exist");
        _;
    }

    modifier onlyBeforeEnd(uint256 auctionId) {
        require(block.timestamp < auctions[auctionId].auctionEndTime, "Auction already ended");
        _;
    }

    modifier onlyAfterEnd(uint256 auctionId) {
        require(block.timestamp >= auctions[auctionId].auctionEndTime, "Auction not yet ended");
        _;
    }

    function createAuction(string memory itemName, uint256 startingPrice) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startingPrice > 0, "Starting price must be greater than 0");

        uint256 auctionId = nextAuctionId++;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: itemName,
            startingPrice: startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            auctionEndTime: block.timestamp + AUCTION_DURATION,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, itemName, startingPrice);
        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable
        auctionExists(auctionId)
        onlyBeforeEnd(auctionId)
    {
        Auction storage auction = auctions[auctionId];
        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
        require(msg.value >= auction.startingPrice, "Bid must meet starting price");

        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) external
        auctionExists(auctionId)
        onlyAfterEnd(auctionId)
    {
        Auction storage auction = auctions[auctionId];
        require(!auction.ended, "Auction already finalized");

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            payable(auction.seller).transfer(auction.highestBid);
        }

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }

    function withdraw(uint256 auctionId) external auctionExists(auctionId) returns (bool) {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[auctionId][msg.sender] = 0;

        payable(msg.sender).transfer(amount);
        emit WithdrawalMade(auctionId, msg.sender, amount);

        return true;
    }

    function getAuctionInfo(uint256 auctionId) external view
        auctionExists(auctionId)
        returns (address, string memory, uint256, uint256, address, uint256, bool)
    {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.ended
        );
    }

    function getPendingReturn(uint256 auctionId, address bidder) external view returns (uint256) {
        return pendingReturns[auctionId][bidder];
    }

    function isAuctionActive(uint256 auctionId) external view auctionExists(auctionId) returns (bool) {
        return block.timestamp < auctions[auctionId].auctionEndTime && !auctions[auctionId].ended;
    }
}
