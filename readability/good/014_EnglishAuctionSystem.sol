
pragma solidity ^0.8.0;


contract EnglishAuctionSystem {


    enum AuctionStatus {
        Active,
        Ended,
        Cancelled
    }


    struct Auction {
        uint256 auctionId;
        address payable seller;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address payable highestBidder;
        uint256 auctionEndTime;
        AuctionStatus status;
        uint256 minimumBidIncrement;
    }


    uint256 private nextAuctionId;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => uint256[]) public userBids;


    address public contractOwner;


    uint256 public platformFeeRate;


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
        uint256 winningBid,
        uint256 timestamp
    );

    event AuctionCancelled(
        uint256 indexed auctionId,
        address indexed seller,
        uint256 timestamp
    );

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(_auctionId < nextAuctionId, "Auction does not exist");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(auctions[_auctionId].status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction has ended");
        _;
    }

    modifier onlySeller(uint256 _auctionId) {
        require(msg.sender == auctions[_auctionId].seller, "Only seller can call this function");
        _;
    }


    constructor(uint256 _platformFeeRate) {
        contractOwner = msg.sender;
        platformFeeRate = _platformFeeRate;
        nextAuctionId = 1;
    }


    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _auctionDuration,
        uint256 _minimumBidIncrement
    ) external returns (uint256 auctionId) {
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_auctionDuration > 0, "Auction duration must be greater than 0");
        require(_minimumBidIncrement > 0, "Minimum bid increment must be greater than 0");

        auctionId = nextAuctionId;
        nextAuctionId++;

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            seller: payable(msg.sender),
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            currentHighestBid: 0,
            highestBidder: payable(address(0)),
            auctionEndTime: block.timestamp + _auctionDuration,
            status: AuctionStatus.Active,
            minimumBidIncrement: _minimumBidIncrement
        });

        userAuctions[msg.sender].push(auctionId);

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _itemName,
            _startingPrice,
            block.timestamp + _auctionDuration
        );
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on their own auction");
        require(msg.value > 0, "Bid amount must be greater than 0");

        uint256 minimumBid;
        if (auction.currentHighestBid == 0) {
            minimumBid = auction.startingPrice;
        } else {
            minimumBid = auction.currentHighestBid + auction.minimumBidIncrement;
        }

        require(msg.value >= minimumBid, "Bid amount is too low");


        if (auction.highestBidder != address(0)) {
            pendingReturns[_auctionId][auction.highestBidder] += auction.currentHighestBid;
        }


        auction.currentHighestBid = msg.value;
        auction.highestBidder = payable(msg.sender);


        userBids[msg.sender].push(_auctionId);

        emit BidPlaced(_auctionId, msg.sender, msg.value, block.timestamp);
    }


    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "Auction cannot be ended yet"
        );
        require(auction.status == AuctionStatus.Active, "Auction is not active");

        auction.status = AuctionStatus.Ended;


        if (auction.highestBidder != address(0)) {
            uint256 platformFee = (auction.currentHighestBid * platformFeeRate) / 10000;
            uint256 sellerAmount = auction.currentHighestBid - platformFee;


            auction.seller.transfer(sellerAmount);


            if (platformFee > 0) {
                payable(contractOwner).transfer(platformFee);
            }
        }

        emit AuctionEnded(
            _auctionId,
            auction.highestBidder,
            auction.currentHighestBid,
            block.timestamp
        );
    }


    function cancelAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlySeller(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(auction.currentHighestBid == 0, "Cannot cancel auction with existing bids");

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(_auctionId, msg.sender, block.timestamp);
    }


    function withdrawBid(uint256 _auctionId) external auctionExists(_auctionId) {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }


    function getAuctionDetails(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (Auction memory auction)
    {
        return auctions[_auctionId];
    }


    function getUserAuctions(address _user) external view returns (uint256[] memory auctionIds) {
        return userAuctions[_user];
    }


    function getUserBids(address _user) external view returns (uint256[] memory auctionIds) {
        return userBids[_user];
    }


    function getPendingReturn(uint256 _auctionId, address _user)
        external
        view
        returns (uint256 amount)
    {
        return pendingReturns[_auctionId][_user];
    }


    function getTotalAuctions() external view returns (uint256 count) {
        return nextAuctionId - 1;
    }


    function updatePlatformFeeRate(uint256 _newFeeRate) external onlyContractOwner {
        require(_newFeeRate <= 1000, "Fee rate cannot exceed 10%");
        platformFeeRate = _newFeeRate;
    }


    function emergencyPause() external onlyContractOwner {

    }
}
