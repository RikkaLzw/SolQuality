
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
        string auctionHash;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;

    uint256 public nextAuctionId;
    uint256 public totalAuctions;
    address public owner;

    event AuctionCreated(uint256 indexed auctionId, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(_auctionId < nextAuctionId, "Auction does not exist");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(uint256(auctions[_auctionId].isActive) == uint256(1), "Auction is not active");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction has ended");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextAuctionId = 0;
        totalAuctions = uint256(0);
    }

    function createAuction(
        string memory _itemName,
        string memory _description,
        uint256 _startingPrice,
        uint256 _duration,
        bytes memory _category,
        string memory _hash
    ) external {
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        auctions[nextAuctionId] = Auction({
            auctionId: nextAuctionId,
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: _startingPrice,
            seller: payable(msg.sender),
            highestBidder: payable(address(0)),
            auctionEndTime: block.timestamp + _duration,
            isActive: uint256(1),
            bidCount: uint256(0),
            auctionCategory: _category,
            auctionHash: _hash
        });

        emit AuctionCreated(nextAuctionId, _itemName, _startingPrice);

        nextAuctionId = uint256(nextAuctionId + 1);
        totalAuctions = uint256(totalAuctions + 1);
    }

    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.currentBid, "Bid must be higher than current bid");


        if (auction.highestBidder != address(0)) {
            bids[_auctionId][auction.highestBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.highestBidder = payable(msg.sender);
        auction.bidCount = uint256(auction.bidCount + 1);

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(
            msg.sender == auction.seller || msg.sender == owner || block.timestamp >= auction.auctionEndTime,
            "Cannot end auction yet"
        );
        require(uint256(auction.isActive) == uint256(1), "Auction already ended");

        auction.isActive = uint256(0);

        if (auction.highestBidder != address(0)) {

            auction.seller.transfer(auction.currentBid);
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.currentBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdrawBid(uint256 _auctionId) external auctionExists(_auctionId) {
        uint256 bidAmount = bids[_auctionId][msg.sender];
        require(bidAmount > 0, "No bid to withdraw");

        bids[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(bidAmount);
    }

    function getAuctionInfo(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (
            string memory itemName,
            string memory description,
            uint256 currentBid,
            address highestBidder,
            uint256 endTime,
            uint256 isActive,
            uint256 bidCount,
            bytes memory category,
            string memory hash
        )
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.itemName,
            auction.description,
            auction.currentBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.isActive,
            auction.bidCount,
            auction.auctionCategory,
            auction.auctionHash
        );
    }

    function getActiveAuctionsCount() external view returns (uint256) {
        uint256 activeCount = uint256(0);

        for (uint256 i = uint256(0); i < nextAuctionId; i = uint256(i + 1)) {
            if (uint256(auctions[i].isActive) == uint256(1) && block.timestamp < auctions[i].auctionEndTime) {
                activeCount = uint256(activeCount + 1);
            }
        }

        return activeCount;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
