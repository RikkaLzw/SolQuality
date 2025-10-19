
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address payable seller;
        string itemName;
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    uint256 public auctionCounter;
    uint256 public constant AUCTION_DURATION = 7 days;

    event AuctionCreated(uint256 indexed auctionId, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);
    event WithdrawalCompleted(address bidder, uint256 amount);

    modifier onlyValidAuction(uint256 auctionId) {
        require(auctions[auctionId].exists, "Auction does not exist");
        _;
    }

    modifier onlyActiveBidding(uint256 auctionId) {
        require(block.timestamp < auctions[auctionId].endTime, "Auction has ended");
        require(!auctions[auctionId].ended, "Auction already finalized");
        _;
    }

    function createAuction(string memory itemName, uint256 startingPrice) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startingPrice > 0, "Starting price must be greater than 0");

        uint256 auctionId = auctionCounter++;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: itemName,
            startingPrice: startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + AUCTION_DURATION,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, itemName, startingPrice);
        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable onlyValidAuction(auctionId) onlyActiveBidding(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.startingPrice, "Bid must exceed starting price");
        require(msg.value > auction.highestBid, "Bid must exceed current highest bid");

        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) external onlyValidAuction(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.endTime, "Auction still active");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            auction.seller.transfer(auction.highestBid);
            emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    function withdraw(uint256 auctionId) external onlyValidAuction(auctionId) returns (bool) {
        uint256 amount = pendingReturns[auctionId][msg.sender];

        require(amount > 0, "No funds to withdraw");

        pendingReturns[auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit WithdrawalCompleted(msg.sender, amount);
        return true;
    }

    function getAuctionInfo(uint256 auctionId) external view onlyValidAuction(auctionId) returns (
        address seller,
        string memory itemName,
        uint256 startingPrice,
        uint256 highestBid
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.startingPrice,
            auction.highestBid
        );
    }

    function getAuctionStatus(uint256 auctionId) external view onlyValidAuction(auctionId) returns (
        address highestBidder,
        uint256 endTime,
        bool ended,
        bool isActive
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.highestBidder,
            auction.endTime,
            auction.ended,
            block.timestamp < auction.endTime && !auction.ended
        );
    }

    function getPendingReturn(uint256 auctionId, address bidder) external view returns (uint256) {
        return pendingReturns[auctionId][bidder];
    }

    function getTotalAuctions() external view returns (uint256) {
        return auctionCounter;
    }
}
