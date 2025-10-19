
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract AuctionSystem is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant MIN_BID_INCREMENT_PERCENTAGE = 5;
    uint256 public constant MAX_AUCTION_DURATION = 30 days;
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 2;
    uint256 public constant BID_EXTENSION_TIME = 10 minutes;


    enum AuctionStatus { Active, Ended, Cancelled }
    enum AuctionType { English, Dutch, Reserve }


    struct Auction {
        uint256 auctionId;
        address seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 currentHighestBid;
        address currentHighestBidder;
        uint256 startTime;
        uint256 endTime;
        AuctionType auctionType;
        AuctionStatus status;
        bool itemDelivered;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private _nextAuctionId = 1;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => uint256[]) public userBids;


    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        uint256 startingPrice,
        AuctionType auctionType,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice
    );

    event AuctionCancelled(uint256 indexed auctionId, address indexed seller);

    event ItemDelivered(uint256 indexed auctionId, address indexed buyer);

    event FundsWithdrawn(address indexed user, uint256 amount);


    modifier validAuctionId(uint256 _auctionId) {
        require(_auctionId > 0 && _auctionId < _nextAuctionId, "Invalid auction ID");
        _;
    }

    modifier onlySeller(uint256 _auctionId) {
        require(auctions[_auctionId].seller == msg.sender, "Only seller can perform this action");
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        require(auctions[_auctionId].status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        _;
    }

    modifier auctionEnded(uint256 _auctionId) {
        require(
            auctions[_auctionId].status == AuctionStatus.Ended ||
            block.timestamp >= auctions[_auctionId].endTime,
            "Auction has not ended yet"
        );
        _;
    }

    modifier validBidAmount(uint256 _auctionId, uint256 _bidAmount) {
        Auction storage auction = auctions[_auctionId];
        if (auction.currentHighestBid == 0) {
            require(_bidAmount >= auction.startingPrice, "Bid must be at least starting price");
        } else {
            uint256 minBid = auction.currentHighestBid.add(
                auction.currentHighestBid.mul(MIN_BID_INCREMENT_PERCENTAGE).div(100)
            );
            require(_bidAmount >= minBid, "Bid increment too small");
        }
        _;
    }

    constructor() {}


    function createAuction(
        string memory _itemName,
        string memory _description,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration,
        AuctionType _auctionType
    ) external returns (uint256) {
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration >= MIN_AUCTION_DURATION && _duration <= MAX_AUCTION_DURATION, "Invalid duration");

        if (_auctionType == AuctionType.Reserve) {
            require(_reservePrice >= _startingPrice, "Reserve price must be >= starting price");
        }

        uint256 auctionId = _nextAuctionId++;
        uint256 endTime = block.timestamp.add(_duration);

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            seller: msg.sender,
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            reservePrice: _reservePrice,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            startTime: block.timestamp,
            endTime: endTime,
            auctionType: _auctionType,
            status: AuctionStatus.Active,
            itemDelivered: false
        });

        userAuctions[msg.sender].push(auctionId);

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, _auctionType, endTime);
        return auctionId;
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        nonReentrant
        validAuctionId(_auctionId)
        auctionActive(_auctionId)
        validBidAmount(_auctionId, msg.value)
    {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > 0, "Bid amount must be greater than 0");


        if (auction.currentHighestBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentHighestBidder] =
                pendingReturns[_auctionId][auction.currentHighestBidder].add(auction.currentHighestBid);
        }


        auction.currentHighestBid = msg.value;
        auction.currentHighestBidder = msg.sender;


        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        userBids[msg.sender].push(_auctionId);


        if (auction.endTime.sub(block.timestamp) < BID_EXTENSION_TIME) {
            auction.endTime = block.timestamp.add(BID_EXTENSION_TIME);
        }

        emit BidPlaced(_auctionId, msg.sender, msg.value, block.timestamp);
    }


    function endAuction(uint256 _auctionId)
        external
        validAuctionId(_auctionId)
        auctionEnded(_auctionId)
        nonReentrant
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Active, "Auction already ended or cancelled");

        auction.status = AuctionStatus.Ended;


        bool reserveMet = true;
        if (auction.auctionType == AuctionType.Reserve &&
            auction.currentHighestBid < auction.reservePrice) {
            reserveMet = false;
        }

        if (auction.currentHighestBidder != address(0) && reserveMet) {

            uint256 platformFee = auction.currentHighestBid.mul(PLATFORM_FEE_PERCENTAGE).div(100);
            uint256 sellerAmount = auction.currentHighestBid.sub(platformFee);


            (bool success, ) = auction.seller.call{value: sellerAmount}("");
            require(success, "Transfer to seller failed");


            (bool feeSuccess, ) = owner().call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");

            emit AuctionEnded(_auctionId, auction.currentHighestBidder, auction.currentHighestBid);
        } else {

            if (auction.currentHighestBidder != address(0)) {
                pendingReturns[_auctionId][auction.currentHighestBidder] =
                    pendingReturns[_auctionId][auction.currentHighestBidder].add(auction.currentHighestBid);
                auction.currentHighestBidder = address(0);
                auction.currentHighestBid = 0;
            }
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }


    function cancelAuction(uint256 _auctionId)
        external
        validAuctionId(_auctionId)
        onlySeller(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.currentHighestBidder == address(0), "Cannot cancel auction with bids");

        auction.status = AuctionStatus.Cancelled;
        emit AuctionCancelled(_auctionId, msg.sender);
    }


    function withdrawPendingReturns(uint256 _auctionId)
        external
        nonReentrant
        validAuctionId(_auctionId)
    {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function markItemDelivered(uint256 _auctionId)
        external
        validAuctionId(_auctionId)
        onlySeller(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Ended, "Auction must be ended");
        require(auction.currentHighestBidder != address(0), "No winner to deliver to");
        require(!auction.itemDelivered, "Item already marked as delivered");

        auction.itemDelivered = true;
        emit ItemDelivered(_auctionId, auction.currentHighestBidder);
    }


    function getAuction(uint256 _auctionId)
        external
        view
        validAuctionId(_auctionId)
        returns (Auction memory)
    {
        return auctions[_auctionId];
    }

    function getAuctionBids(uint256 _auctionId)
        external
        view
        validAuctionId(_auctionId)
        returns (Bid[] memory)
    {
        return auctionBids[_auctionId];
    }

    function getUserAuctions(address _user) external view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function getUserBids(address _user) external view returns (uint256[] memory) {
        return userBids[_user];
    }

    function getPendingReturns(uint256 _auctionId, address _user)
        external
        view
        returns (uint256)
    {
        return pendingReturns[_auctionId][_user];
    }

    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }

    function getTotalAuctions() external view returns (uint256) {
        return _nextAuctionId - 1;
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }


    receive() external payable {}
}
