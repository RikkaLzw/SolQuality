
pragma solidity ^0.8.0;


contract AuctionSystem {

    enum AuctionState {
        Active,
        Ended,
        Cancelled
    }


    struct Auction {
        address payable seller;
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
    address public owner;
    uint256 public platformFeePercentage;


    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemDescription,
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


    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(_auctionId < nextAuctionId, "Auction does not exist");
        _;
    }

    modifier onlyActiveBid(uint256 _auctionId) {
        require(auctions[_auctionId].state == AuctionState.Active, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction has ended");
        _;
    }


    constructor(uint256 _platformFeePercentage) {
        owner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
        nextAuctionId = 0;
    }


    function createAuction(
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _durationInHours
    ) external returns (uint256 auctionId) {
        require(bytes(_itemDescription).length > 0, "Item description cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_durationInHours > 0 && _durationInHours <= 168, "Duration must be between 1 and 168 hours");

        auctionId = nextAuctionId;
        nextAuctionId++;

        uint256 endTime = block.timestamp + (_durationInHours * 1 hours);

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            auctionEndTime: endTime,
            state: AuctionState.Active,
            sellerWithdrawn: false
        });

        emit AuctionCreated(auctionId, msg.sender, _itemDescription, _startingPrice, endTime);
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        onlyActiveBid(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on their own auction");
        require(msg.value > auction.startingPrice, "Bid must be higher than starting price");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");


        if (auction.highestBidder != address(0)) {
            pendingReturns[_auctionId][auction.highestBidder] += auction.highestBid;
        }


        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }


    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(auction.state == AuctionState.Active, "Auction is not active");
        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "Auction cannot be ended yet"
        );

        auction.state = AuctionState.Ended;

        emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
    }


    function cancelAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender == auction.seller, "Only seller can cancel auction");
        require(auction.state == AuctionState.Active, "Auction is not active");
        require(auction.highestBidder == address(0), "Cannot cancel auction with existing bids");

        auction.state = AuctionState.Cancelled;

        emit AuctionCancelled(_auctionId);
    }


    function withdrawSellerFunds(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender == auction.seller, "Only seller can withdraw");
        require(auction.state == AuctionState.Ended, "Auction must be ended");
        require(!auction.sellerWithdrawn, "Funds already withdrawn");
        require(auction.highestBidder != address(0), "No winning bid to withdraw");

        auction.sellerWithdrawn = true;

        uint256 platformFee = (auction.highestBid * platformFeePercentage) / 10000;
        uint256 sellerAmount = auction.highestBid - platformFee;


        (bool success, ) = auction.seller.call{value: sellerAmount}("");
        require(success, "Transfer to seller failed");


        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(owner).call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");
        }

        emit FundsWithdrawn(_auctionId, auction.seller, sellerAmount);
    }


    function withdrawBid(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }


    function getAuctionDetails(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (
            address seller,
            string memory itemDescription,
            uint256 startingPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 auctionEndTime,
            AuctionState state,
            bool sellerWithdrawn
        )
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemDescription,
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.state,
            auction.sellerWithdrawn
        );
    }


    function isAuctionEnded(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (bool)
    {
        return block.timestamp >= auctions[_auctionId].auctionEndTime;
    }


    function getPendingReturn(uint256 _auctionId, address _bidder)
        external
        view
        auctionExists(_auctionId)
        returns (uint256)
    {
        return pendingReturns[_auctionId][_bidder];
    }


    function updatePlatformFee(uint256 _newFeePercentage)
        external
        onlyOwner
    {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }


    function getTotalAuctions() external view returns (uint256) {
        return nextAuctionId;
    }
}
