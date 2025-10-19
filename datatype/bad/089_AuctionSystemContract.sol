
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Auction {
        uint256 auctionId;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address payable seller;
        address payable highestBidder;
        uint256 auctionEndTime;
        uint256 isActive;
        uint256 bidCount;
        bytes auctionCategory;
        string fixedLengthId;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;

    uint256 public auctionCounter;
    uint256 public totalActiveAuctions;
    uint256 public systemStatus;

    address public owner;
    uint256 public commissionRate;

    event AuctionCreated(uint256 indexed auctionId, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(_auctionId < auctionCounter, "Auction does not exist");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(auctions[_auctionId].isActive == uint256(1), "Auction is not active");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction has ended");
        _;
    }

    constructor() {
        owner = msg.sender;
        systemStatus = uint256(1);
        commissionRate = uint256(5);
        auctionCounter = uint256(0);
        totalActiveAuctions = uint256(0);
    }

    function createAuction(
        string memory _itemName,
        string memory _description,
        uint256 _startingPrice,
        uint256 _duration,
        bytes memory _category,
        string memory _fixedId
    ) external {
        require(systemStatus == uint256(1), "System is not active");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        uint256 newAuctionId = auctionCounter;

        auctions[newAuctionId] = Auction({
            auctionId: newAuctionId,
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: uint256(0),
            seller: payable(msg.sender),
            highestBidder: payable(address(0)),
            auctionEndTime: block.timestamp + _duration,
            isActive: uint256(1),
            bidCount: uint256(0),
            auctionCategory: _category,
            fixedLengthId: _fixedId
        });

        auctionCounter = auctionCounter + uint256(1);
        totalActiveAuctions = totalActiveAuctions + uint256(1);

        emit AuctionCreated(newAuctionId, _itemName, _startingPrice);
    }

    function placeBid(uint256 _auctionId) external payable auctionExists(_auctionId) auctionActive(_auctionId) {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.currentBid, "Bid must be higher than current bid");
        require(msg.value >= auction.startingPrice, "Bid must be at least starting price");

        if (auction.highestBidder != address(0)) {
            pendingReturns[auction.highestBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.highestBidder = payable(msg.sender);
        auction.bidCount = auction.bidCount + uint256(1);

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external auctionExists(_auctionId) {
        Auction storage auction = auctions[_auctionId];

        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "Auction cannot be ended yet"
        );
        require(auction.isActive == uint256(1), "Auction already ended");

        auction.isActive = uint256(0);
        totalActiveAuctions = totalActiveAuctions - uint256(1);

        if (auction.highestBidder != address(0)) {
            uint256 commission = (auction.currentBid * commissionRate) / uint256(100);
            uint256 sellerAmount = auction.currentBid - commission;

            auction.seller.transfer(sellerAmount);
            payable(owner).transfer(commission);

            emit AuctionEnded(_auctionId, auction.highestBidder, auction.currentBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), uint256(0));
        }
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = uint256(0);
        payable(msg.sender).transfer(amount);
    }

    function getAuctionDetails(uint256 _auctionId) external view auctionExists(_auctionId) returns (
        string memory itemName,
        string memory description,
        uint256 currentBid,
        address highestBidder,
        uint256 endTime,
        uint256 isActive,
        uint256 bidCount,
        bytes memory category
    ) {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.itemName,
            auction.description,
            auction.currentBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.isActive,
            auction.bidCount,
            auction.auctionCategory
        );
    }

    function setSystemStatus(uint256 _status) external onlyOwner {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        systemStatus = _status;
    }

    function setCommissionRate(uint256 _rate) external onlyOwner {
        require(_rate <= uint256(100), "Commission rate cannot exceed 100%");
        commissionRate = _rate;
    }

    function getActiveAuctionsCount() external view returns (uint256) {
        return totalActiveAuctions;
    }

    function isAuctionActive(uint256 _auctionId) external view auctionExists(_auctionId) returns (uint256) {
        return auctions[_auctionId].isActive;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
