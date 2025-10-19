
pragma solidity ^0.8.0;


contract AuctionSystem {

    enum AuctionState {
        Active,
        Ended,
        Cancelled
    }


    struct Auction {
        address payable seller;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 auctionEndTime;
        AuctionState state;
        bool sellerWithdrawn;
    }


    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    uint256 public nextAuctionId;
    uint256 public platformFeeRate;
    address payable public platformOwner;


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
        uint256 bidAmount
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(uint256 indexed auctionId);

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed recipient,
        uint256 amount
    );


    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier auctionExists(uint256 auctionId) {
        require(auctionId < nextAuctionId, "Auction does not exist");
        _;
    }

    modifier onlyAuctionSeller(uint256 auctionId) {
        require(msg.sender == auctions[auctionId].seller, "Only auction seller can call this function");
        _;
    }


    constructor(uint256 _platformFeeRate) {
        require(_platformFeeRate <= 1000, "Platform fee rate cannot exceed 10%");
        platformOwner = payable(msg.sender);
        platformFeeRate = _platformFeeRate;
        nextAuctionId = 0;
    }


    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _durationInMinutes
    ) external returns (uint256) {
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_durationInMinutes > 0, "Duration must be greater than 0");
        require(_durationInMinutes <= 10080, "Duration cannot exceed 7 days");

        uint256 auctionId = nextAuctionId;
        uint256 endTime = block.timestamp + (_durationInMinutes * 1 minutes);

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            auctionEndTime: endTime,
            state: AuctionState.Active,
            sellerWithdrawn: false
        });

        nextAuctionId++;

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, endTime);

        return auctionId;
    }


    function placeBid(uint256 auctionId) external payable auctionExists(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(auction.state == AuctionState.Active, "Auction is not active");
        require(block.timestamp < auction.auctionEndTime, "Auction has ended");
        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid must be greater than 0");


        uint256 minimumBid = auction.highestBid > 0 ? auction.highestBid : auction.startingPrice;
        require(msg.value > minimumBid, "Bid must be higher than current highest bid or starting price");


        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }


        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }


    function endAuction(uint256 auctionId) external auctionExists(auctionId) {
        Auction storage auction = auctions[auctionId];

        require(auction.state == AuctionState.Active, "Auction is not active");
        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "Auction cannot be ended yet"
        );

        auction.state = AuctionState.Ended;

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }


    function cancelAuction(uint256 auctionId)
        external
        auctionExists(auctionId)
        onlyAuctionSeller(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(auction.state == AuctionState.Active, "Auction is not active");
        require(auction.highestBidder == address(0), "Cannot cancel auction with existing bids");

        auction.state = AuctionState.Cancelled;

        emit AuctionCancelled(auctionId);
    }


    function withdrawSellerFunds(uint256 auctionId)
        external
        auctionExists(auctionId)
        onlyAuctionSeller(auctionId)
    {
        Auction storage auction = auctions[auctionId];

        require(auction.state == AuctionState.Ended, "Auction has not ended");
        require(auction.highestBidder != address(0), "No bids were placed");
        require(!auction.sellerWithdrawn, "Funds already withdrawn");

        auction.sellerWithdrawn = true;


        uint256 platformFee = (auction.highestBid * platformFeeRate) / 10000;
        uint256 sellerAmount = auction.highestBid - platformFee;


        auction.seller.transfer(sellerAmount);


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }

        emit FundsWithdrawn(auctionId, auction.seller, sellerAmount);
    }


    function withdrawBid(uint256 auctionId) external auctionExists(auctionId) {
        uint256 amount = pendingReturns[auctionId][msg.sender];

        require(amount > 0, "No funds to withdraw");

        pendingReturns[auctionId][msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(auctionId, msg.sender, amount);
    }


    function getAuctionDetails(uint256 auctionId)
        external
        view
        auctionExists(auctionId)
        returns (
            address seller,
            string memory itemName,
            string memory itemDescription,
            uint256 startingPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 auctionEndTime,
            AuctionState state,
            bool sellerWithdrawn
        )
    {
        Auction storage auction = auctions[auctionId];

        return (
            auction.seller,
            auction.itemName,
            auction.itemDescription,
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.state,
            auction.sellerWithdrawn
        );
    }


    function getPendingReturn(uint256 auctionId, address bidder)
        external
        view
        auctionExists(auctionId)
        returns (uint256)
    {
        return pendingReturns[auctionId][bidder];
    }


    function updatePlatformFeeRate(uint256 _newFeeRate) external onlyPlatformOwner {
        require(_newFeeRate <= 1000, "Platform fee rate cannot exceed 10%");
        platformFeeRate = _newFeeRate;
    }


    function transferPlatformOwnership(address payable _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }


    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }
}
