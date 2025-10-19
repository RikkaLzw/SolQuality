
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address payable seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address payable currentBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    uint256 public nextAuctionId;
    uint256 public constant MINIMUM_AUCTION_DURATION = 1 hours;
    uint256 public constant MINIMUM_BID_INCREMENT = 0.01 ether;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        uint256 startingPrice,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount,
        uint256 timestamp
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    modifier auctionExists(uint256 _auctionId) {
        require(auctions[_auctionId].exists, "Auction does not exist");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(!auctions[_auctionId].ended, "Auction has been finalized");
        _;
    }

    modifier onlySeller(uint256 _auctionId) {
        require(msg.sender == auctions[_auctionId].seller, "Only seller can perform this action");
        _;
    }

    function createAuction(
        string memory _itemName,
        string memory _description,
        uint256 _startingPrice,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration >= MINIMUM_AUCTION_DURATION, "Auction duration too short");

        uint256 auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: payable(address(0)),
            endTime: endTime,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, endTime);
        return auctionId;
    }

    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid amount must be greater than 0");

        uint256 minimumBid = auction.currentBid == 0 ?
            auction.startingPrice :
            auction.currentBid + MINIMUM_BID_INCREMENT;

        require(msg.value >= minimumBid, "Bid amount too low");


        if (auction.currentBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.currentBidder = payable(msg.sender);

        emit BidPlaced(_auctionId, msg.sender, msg.value, block.timestamp);
    }

    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction already finalized");

        auction.ended = true;

        if (auction.currentBidder != address(0)) {

            auction.seller.transfer(auction.currentBid);
            emit AuctionEnded(_auctionId, auction.currentBidder, auction.currentBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdraw(uint256 _auctionId) external auctionExists(_auctionId) {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }

    function emergencyEndAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlySeller(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(!auction.ended, "Auction already finalized");

        auction.ended = true;


        if (auction.currentBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentBidder] += auction.currentBid;
            auction.currentBid = 0;
            auction.currentBidder = payable(address(0));
        }

        emit AuctionEnded(_auctionId, address(0), 0);
    }

    function getAuctionDetails(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (
            address seller,
            string memory itemName,
            string memory description,
            uint256 startingPrice,
            uint256 currentBid,
            address currentBidder,
            uint256 endTime,
            bool ended,
            uint256 timeRemaining
        )
    {
        Auction storage auction = auctions[_auctionId];
        uint256 remaining = block.timestamp >= auction.endTime ? 0 : auction.endTime - block.timestamp;

        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.ended,
            remaining
        );
    }

    function getPendingReturn(uint256 _auctionId, address _bidder)
        external
        view
        auctionExists(_auctionId)
        returns (uint256)
    {
        return pendingReturns[_auctionId][_bidder];
    }

    function isAuctionActive(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (bool)
    {
        Auction storage auction = auctions[_auctionId];
        return block.timestamp < auction.endTime && !auction.ended;
    }
}
