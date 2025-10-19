
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        address seller;
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
    uint256 public platformFee = 250;

    error InvalidInput();
    error NotAuthorized();
    error AuctionError();
    error TransferFailed();

    event AuctionCreated(uint256 auctionId, address seller, uint256 startingPrice);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createAuction(uint256 _startingPrice, uint256 _duration) external {
        require(_startingPrice > 0);
        require(_duration > 0);

        uint256 auctionId = nextAuctionId++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, _startingPrice);
    }

    function placeBid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];
        require(auction.exists);
        require(block.timestamp < auction.endTime);
        require(!auction.ended);
        require(msg.value > auction.currentBid);
        require(msg.value >= auction.startingPrice);
        require(msg.sender != auction.seller);

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

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success);
    }

    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(auction.exists);
        require(block.timestamp >= auction.endTime);
        require(!auction.ended);

        auction.ended = true;

        if (auction.currentBidder != address(0)) {
            uint256 fee = (auction.currentBid * platformFee) / 10000;
            uint256 sellerAmount = auction.currentBid - fee;

            (bool success1, ) = payable(auction.seller).call{value: sellerAmount}("");
            require(success1);

            (bool success2, ) = payable(owner).call{value: fee}("");
            require(success2);
        }

        emit AuctionEnded(_auctionId, auction.currentBidder, auction.currentBid);
    }

    function getAuction(uint256 _auctionId) external view returns (
        address seller,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction storage auction = auctions[_auctionId];
        require(auction.exists);

        return (
            auction.seller,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.ended
        );
    }

    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000);
        platformFee = _fee;
    }

    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success);
    }
}
