
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address seller;
        string itemName;
        uint256 startingPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    uint256 public nextAuctionId;
    address public owner;
    uint256 public platformFee = 25;

    error Error1();
    error Error2();
    error Error3();

    event AuctionCreated(uint256 auctionId, address seller, string itemName);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        nextAuctionId = 1;
    }

    function createAuction(
        string memory _itemName,
        uint256 _startingPrice,
        uint256 _duration
    ) external {
        require(_startingPrice > 0);
        require(_duration > 0);
        require(bytes(_itemName).length > 0);

        uint256 auctionId = nextAuctionId++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: _itemName,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, _itemName);
    }

    function placeBid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        require(auction.exists);
        require(block.timestamp < auction.endTime);
        require(!auction.ended);
        require(msg.sender != auction.seller);
        require(msg.value > auction.currentBid);
        require(msg.value >= auction.startingPrice);

        if (auction.currentBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.currentBidder = msg.sender;

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function withdraw(uint256 _auctionId) external {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0);

        pendingReturns[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        require(auction.exists);
        require(block.timestamp >= auction.endTime || msg.sender == auction.seller);
        require(!auction.ended);

        auction.ended = true;

        if (auction.currentBidder != address(0)) {
            uint256 fee = (auction.currentBid * platformFee) / 1000;
            uint256 sellerAmount = auction.currentBid - fee;

            payable(auction.seller).transfer(sellerAmount);
            payable(owner).transfer(fee);

            emit AuctionEnded(_auctionId, auction.currentBidder, auction.currentBid);
        }
    }

    function getAuction(uint256 _auctionId) external view returns (
        address seller,
        string memory itemName,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended
    ) {
        require(auctions[_auctionId].exists);

        Auction memory auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.ended
        );
    }

    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100);
        platformFee = _fee;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function isAuctionActive(uint256 _auctionId) external view returns (bool) {
        Auction memory auction = auctions[_auctionId];
        return auction.exists && !auction.ended && block.timestamp < auction.endTime;
    }

    function getHighestBid(uint256 _auctionId) external view returns (uint256, address) {
        require(auctions[_auctionId].exists);
        return (auctions[_auctionId].currentBid, auctions[_auctionId].currentBidder);
    }
}
