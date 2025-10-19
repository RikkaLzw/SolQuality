
pragma solidity ^0.8.0;


contract AuctionSystem {

    enum AuctionState {
        Created,
        Active,
        Ended,
        Cancelled
    }


    struct AuctionInfo {
        address payable seller;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentHighestBid;
        address payable highestBidder;
        uint256 auctionEndTime;
        AuctionState state;
        bool sellerWithdrawn;
    }


    mapping(uint256 => AuctionInfo) public auctions;
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
        uint256 bidAmount,
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
        address indexed recipient,
        uint256 amount
    );


    modifier onlyAuctionSeller(uint256 _auctionId) {
        require(
            auctions[_auctionId].seller == msg.sender,
            "Only auction seller can perform this action"
        );
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(
            _auctionId < nextAuctionId,
            "Auction does not exist"
        );
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(
            auctions[_auctionId].state == AuctionState.Active,
            "Auction is not active"
        );
        require(
            block.timestamp < auctions[_auctionId].auctionEndTime,
            "Auction has ended"
        );
        _;
    }


    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration
    ) external returns (uint256 auctionId) {

        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_reservePrice >= _startingPrice, "Reserve price must be >= starting price");
        require(
            _duration >= MINIMUM_AUCTION_DURATION && _duration <= MAXIMUM_AUCTION_DURATION,
            "Invalid auction duration"
        );


        auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionId] = AuctionInfo({
            seller: payable(msg.sender),
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            reservePrice: _reservePrice,
            currentHighestBid: 0,
            highestBidder: payable(address(0)),
            auctionEndTime: endTime,
            state: AuctionState.Active,
            sellerWithdrawn: false
        });

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _itemName,
            _startingPrice,
            _reservePrice,
            endTime
        );
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        AuctionInfo storage auction = auctions[_auctionId];


        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid must be greater than 0");

        uint256 minimumBid = auction.currentHighestBid > 0
            ? auction.currentHighestBid + 1 wei
            : auction.startingPrice;

        require(msg.value >= minimumBid, "Bid too low");


        if (auction.highestBidder != address(0)) {
            pendingReturns[_auctionId][auction.highestBidder] += auction.currentHighestBid;
        }


        auction.currentHighestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit BidPlaced(_auctionId, msg.sender, msg.value, block.timestamp);
    }


    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        AuctionInfo storage auction = auctions[_auctionId];

        require(
            auction.state == AuctionState.Active,
            "Auction is not active"
        );
        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "Auction cannot be ended yet"
        );

        auction.state = AuctionState.Ended;

        emit AuctionEnded(
            _auctionId,
            auction.highestBidder,
            auction.currentHighestBid
        );
    }


    function cancelAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlyAuctionSeller(_auctionId)
    {
        AuctionInfo storage auction = auctions[_auctionId];

        require(
            auction.state == AuctionState.Active,
            "Auction is not active"
        );
        require(
            auction.currentHighestBid == 0,
            "Cannot cancel auction with existing bids"
        );

        auction.state = AuctionState.Cancelled;

        emit AuctionCancelled(_auctionId, msg.sender);
    }


    function withdrawSellerFunds(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlyAuctionSeller(_auctionId)
    {
        AuctionInfo storage auction = auctions[_auctionId];

        require(
            auction.state == AuctionState.Ended,
            "Auction has not ended"
        );
        require(
            !auction.sellerWithdrawn,
            "Funds already withdrawn"
        );
        require(
            auction.currentHighestBid >= auction.reservePrice,
            "Reserve price not met"
        );

        auction.sellerWithdrawn = true;
        uint256 amount = auction.currentHighestBid;

        (bool success, ) = auction.seller.call{value: amount}("");
        require(success, "Transfer to seller failed");

        emit FundsWithdrawn(_auctionId, auction.seller, amount);
    }


    function withdrawBid(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }


    function getAuctionInfo(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (AuctionInfo memory)
    {
        return auctions[_auctionId];
    }


    function getPendingReturn(uint256 _auctionId, address _bidder)
        external
        view
        returns (uint256)
    {
        return pendingReturns[_auctionId][_bidder];
    }


    function isAuctionEnded(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (bool)
    {
        return block.timestamp >= auctions[_auctionId].auctionEndTime;
    }


    function getTotalAuctions() external view returns (uint256) {
        return nextAuctionId;
    }
}
