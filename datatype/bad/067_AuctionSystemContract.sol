
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Auction {
        uint256 auctionId;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address payable highestBidder;
        uint256 auctionEndTime;
        uint256 isActive;
        uint256 bidCount;
        bytes auctionCategory;
        string auctionHash;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;

    uint256 public nextAuctionId;
    uint256 public totalAuctions;
    uint256 public contractStatus;

    address payable public owner;
    uint256 public commissionRate;

    event AuctionCreated(uint256 indexed auctionId, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);

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
        owner = payable(msg.sender);
        nextAuctionId = uint256(0);
        totalAuctions = uint256(0);
        contractStatus = uint256(1);
        commissionRate = uint256(5);
    }

    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _duration,
        bytes memory _category,
        string memory _hash
    ) external {
        require(uint256(contractStatus) == uint256(1), "Contract is not active");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        uint256 auctionId = nextAuctionId;

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            currentHighestBid: uint256(0),
            highestBidder: payable(address(0)),
            auctionEndTime: block.timestamp + _duration,
            isActive: uint256(1),
            bidCount: uint256(0),
            auctionCategory: _category,
            auctionHash: _hash
        });

        nextAuctionId = uint256(nextAuctionId + uint256(1));
        totalAuctions = uint256(totalAuctions + uint256(1));

        emit AuctionCreated(auctionId, _itemName, _startingPrice);
    }

    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.value > auction.currentHighestBid, "Bid must be higher than current highest bid");
        require(msg.value >= auction.startingPrice, "Bid must be at least the starting price");

        if (auction.highestBidder != address(0)) {
            pendingReturns[auction.highestBidder] += auction.currentHighestBid;
        }

        auction.currentHighestBid = msg.value;
        auction.highestBidder = payable(msg.sender);
        auction.bidCount = uint256(auction.bidCount + uint256(1));

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(uint256(auction.isActive) == uint256(1), "Auction is already ended");
        require(block.timestamp >= auction.auctionEndTime, "Auction has not ended yet");

        auction.isActive = uint256(0);

        if (auction.highestBidder != address(0)) {
            uint256 commission = (auction.currentHighestBid * commissionRate) / uint256(100);
            uint256 sellerAmount = auction.currentHighestBid - commission;

            owner.transfer(commission);


        }

        emit AuctionEnded(_auctionId, auction.highestBidder, auction.currentHighestBid);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = uint256(0);
        payable(msg.sender).transfer(amount);
    }

    function getAuctionDetails(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (
            string memory itemName,
            string memory itemDescription,
            uint256 startingPrice,
            uint256 currentHighestBid,
            address highestBidder,
            uint256 auctionEndTime,
            uint256 isActive,
            uint256 bidCount,
            bytes memory category,
            string memory hash
        )
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.itemName,
            auction.itemDescription,
            auction.startingPrice,
            auction.currentHighestBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.isActive,
            auction.bidCount,
            auction.auctionCategory,
            auction.auctionHash
        );
    }

    function isAuctionActive(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (uint256)
    {
        return uint256(auctions[_auctionId].isActive == uint256(1) &&
                      block.timestamp < auctions[_auctionId].auctionEndTime ? uint256(1) : uint256(0));
    }

    function setCommissionRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= uint256(100), "Commission rate cannot exceed 100%");
        commissionRate = _newRate;
    }

    function toggleContractStatus() external onlyOwner {
        contractStatus = uint256(contractStatus == uint256(1) ? uint256(0) : uint256(1));
    }

    function getContractStats()
        external
        view
        returns (uint256 totalAuctionsCount, uint256 activeAuctionsCount, uint256 status)
    {
        uint256 activeCount = uint256(0);

        for (uint256 i = uint256(0); i < nextAuctionId; i = uint256(i + uint256(1))) {
            if (uint256(auctions[i].isActive) == uint256(1) &&
                block.timestamp < auctions[i].auctionEndTime) {
                activeCount = uint256(activeCount + uint256(1));
            }
        }

        return (totalAuctions, activeCount, contractStatus);
    }
}
