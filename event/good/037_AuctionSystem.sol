
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address payable seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address payable currentBidder;
        uint256 startTime;
        uint256 endTime;
        bool ended;
        bool cancelled;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

    uint256 public nextAuctionId;
    uint256 public constant MINIMUM_AUCTION_DURATION = 1 hours;
    uint256 public constant MAXIMUM_AUCTION_DURATION = 30 days;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(
        uint256 indexed auctionId,
        address indexed seller
    );

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    modifier onlyValidAuction(uint256 auctionId) {
        require(auctionId < nextAuctionId, "Auction does not exist");
        _;
    }

    modifier onlyActiveBidding(uint256 auctionId) {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.startTime, "Auction has not started yet");
        require(block.timestamp < auction.endTime, "Auction has already ended");
        require(!auction.ended, "Auction has been finalized");
        require(!auction.cancelled, "Auction has been cancelled");
        _;
    }

    modifier onlySeller(uint256 auctionId) {
        require(auctions[auctionId].seller == msg.sender, "Only seller can perform this action");
        _;
    }

    function createAuction(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration
    ) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startingPrice > 0, "Starting price must be greater than zero");
        require(reservePrice >= startingPrice, "Reserve price must be at least starting price");
        require(duration >= MINIMUM_AUCTION_DURATION, "Auction duration too short");
        require(duration <= MAXIMUM_AUCTION_DURATION, "Auction duration too long");

        uint256 auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            reservePrice: reservePrice,
            currentBid: 0,
            currentBidder: payable(address(0)),
            startTime: block.timestamp,
            endTime: endTime,
            ended: false,
            cancelled: false
        });

        emit AuctionCreated(
            auctionId,
            msg.sender,
            itemName,
            startingPrice,
            reservePrice,
            endTime
        );

        return auctionId;
    }

    function placeBid(uint256 auctionId)
        external
        payable
        onlyValidAuction(auctionId)
        onlyActiveBidding(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid amount must be greater than zero");

        uint256 minimumBid = auction.currentBid == 0 ? auction.startingPrice : auction.currentBid + 1;
        require(msg.value >= minimumBid, "Bid amount too low");


        if (auction.currentBidder != address(0)) {
            pendingReturns[auctionId][auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.currentBidder = payable(msg.sender);

        emit BidPlaced(auctionId, msg.sender, msg.value, block.timestamp);
    }

    function endAuction(uint256 auctionId)
        external
        onlyValidAuction(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction already finalized");
        require(!auction.cancelled, "Auction was cancelled");

        auction.ended = true;

        if (auction.currentBidder != address(0) && auction.currentBid >= auction.reservePrice) {

            auction.seller.transfer(auction.currentBid);
            emit AuctionEnded(auctionId, auction.currentBidder, auction.currentBid);
        } else {

            if (auction.currentBidder != address(0)) {
                pendingReturns[auctionId][auction.currentBidder] += auction.currentBid;
            }
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    function cancelAuction(uint256 auctionId)
        external
        onlyValidAuction(auctionId)
        onlySeller(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(!auction.ended, "Cannot cancel ended auction");
        require(!auction.cancelled, "Auction already cancelled");

        auction.cancelled = true;


        if (auction.currentBidder != address(0)) {
            pendingReturns[auctionId][auction.currentBidder] += auction.currentBid;
        }

        emit AuctionCancelled(auctionId, msg.sender);
    }

    function withdraw(uint256 auctionId) external onlyValidAuction(auctionId) {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(auctionId, msg.sender, amount);
    }

    function getAuctionDetails(uint256 auctionId)
        external
        view
        onlyValidAuction(auctionId)
        returns (
            address seller,
            string memory itemName,
            string memory description,
            uint256 startingPrice,
            uint256 reservePrice,
            uint256 currentBid,
            address currentBidder,
            uint256 startTime,
            uint256 endTime,
            bool ended,
            bool cancelled
        )
    {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.reservePrice,
            auction.currentBid,
            auction.currentBidder,
            auction.startTime,
            auction.endTime,
            auction.ended,
            auction.cancelled
        );
    }

    function isAuctionActive(uint256 auctionId)
        external
        view
        onlyValidAuction(auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        return (
            block.timestamp >= auction.startTime &&
            block.timestamp < auction.endTime &&
            !auction.ended &&
            !auction.cancelled
        );
    }

    function getPendingReturn(uint256 auctionId, address bidder)
        external
        view
        onlyValidAuction(auctionId)
        returns (uint256)
    {
        return pendingReturns[auctionId][bidder];
    }
}
