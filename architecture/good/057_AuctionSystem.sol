
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
        uint256 reservePrice;
        uint256 currentHighestBid;
        address payable currentHighestBidder;
        uint256 startTime;
        uint256 endTime;
        AuctionStatus status;
        bool fundsWithdrawn;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private _nextAuctionId;
    mapping(uint256 => Auction) private _auctions;
    mapping(uint256 => Bid[]) private _auctionBids;
    mapping(uint256 => mapping(address => uint256)) private _pendingReturns;
    mapping(address => uint256[]) private _userAuctions;
    mapping(address => uint256[]) private _userBids;


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
        uint256 amount,
        uint256 timestamp
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(uint256 indexed auctionId, address indexed seller);

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed recipient,
        uint256 amount
    );

    event BidRefunded(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );


    modifier auctionExists(uint256 auctionId) {
        require(_auctions[auctionId].seller != address(0), "Auction does not exist");
        _;
    }

    modifier onlyActiveBid(uint256 auctionId) {
        require(_auctions[auctionId].status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp < _auctions[auctionId].endTime, "Auction has ended");
        _;
    }

    modifier onlyAuctionSeller(uint256 auctionId) {
        require(_auctions[auctionId].seller == msg.sender, "Only auction seller allowed");
        _;
    }

    modifier validBidAmount(uint256 auctionId, uint256 bidAmount) {
        Auction storage auction = _auctions[auctionId];
        uint256 minBid = auction.currentHighestBid == 0
            ? auction.startingPrice
            : auction.currentHighestBid.add(
                auction.currentHighestBid.mul(MIN_BID_INCREMENT_PERCENTAGE).div(100)
            );
        require(bidAmount >= minBid, "Bid amount too low");
        _;
    }

    constructor() {
        _nextAuctionId = 1;
    }


    function createAuction(
        string memory itemName,
        string memory itemDescription,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration
    ) external returns (uint256) {
        require(bytes(itemName).length > 0, "Item name cannot be empty");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(reservePrice >= startingPrice, "Reserve price must be >= starting price");
        require(
            duration >= MIN_AUCTION_DURATION && duration <= MAX_AUCTION_DURATION,
            "Invalid auction duration"
        );

        uint256 auctionId = _nextAuctionId++;
        uint256 endTime = block.timestamp.add(duration);

        _auctions[auctionId] = Auction({
            auctionId: auctionId,
            seller: payable(msg.sender),
            itemName: itemName,
            itemDescription: itemDescription,
            startingPrice: startingPrice,
            reservePrice: reservePrice,
            currentHighestBid: 0,
            currentHighestBidder: payable(address(0)),
            startTime: block.timestamp,
            endTime: endTime,
            status: AuctionStatus.Active,
            fundsWithdrawn: false
        });

        _userAuctions[msg.sender].push(auctionId);

        emit AuctionCreated(
            auctionId,
            msg.sender,
            itemName,
            startingPrice,
            reservePrice,
            endTime
        );

        return auctionId;
    }


    function placeBid(uint256 auctionId)
        external
        payable
        nonReentrant
        auctionExists(auctionId)
        onlyActiveBid(auctionId)
        validBidAmount(auctionId, msg.value)
    {
        Auction storage auction = _auctions[auctionId];
        require(msg.sender != auction.seller, "Seller cannot bid on own auction");


        if (auction.currentHighestBidder != address(0)) {
            _pendingReturns[auctionId][auction.currentHighestBidder] =
                _pendingReturns[auctionId][auction.currentHighestBidder].add(auction.currentHighestBid);
        }


        auction.currentHighestBid = msg.value;
        auction.currentHighestBidder = payable(msg.sender);


        _auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        _userBids[msg.sender].push(auctionId);

        emit BidPlaced(auctionId, msg.sender, msg.value, block.timestamp);
    }


    function endAuction(uint256 auctionId)
        external
        nonReentrant
        auctionExists(auctionId)
    {
        Auction storage auction = _auctions[auctionId];
        require(auction.status == AuctionStatus.Active, "Auction already ended or cancelled");
        require(block.timestamp >= auction.endTime, "Auction has not ended yet");

        auction.status = AuctionStatus.Ended;

        emit AuctionEnded(
            auctionId,
            auction.currentHighestBidder,
            auction.currentHighestBid
        );
    }


    function cancelAuction(uint256 auctionId)
        external
        auctionExists(auctionId)
        onlyAuctionSeller(auctionId)
    {
        Auction storage auction = _auctions[auctionId];
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(auction.currentHighestBid == 0, "Cannot cancel auction with bids");

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(auctionId, msg.sender);
    }


    function withdrawFunds(uint256 auctionId)
        external
        nonReentrant
        auctionExists(auctionId)
    {
        Auction storage auction = _auctions[auctionId];
        require(auction.status == AuctionStatus.Ended, "Auction not ended");
        require(!auction.fundsWithdrawn, "Funds already withdrawn");
        require(msg.sender == auction.seller, "Only seller can withdraw");

        if (auction.currentHighestBid >= auction.reservePrice) {
            auction.fundsWithdrawn = true;

            uint256 platformFee = auction.currentHighestBid.mul(PLATFORM_FEE_PERCENTAGE).div(100);
            uint256 sellerAmount = auction.currentHighestBid.sub(platformFee);


            auction.seller.transfer(sellerAmount);


            payable(owner()).transfer(platformFee);

            emit FundsWithdrawn(auctionId, auction.seller, sellerAmount);
        } else {

            auction.fundsWithdrawn = true;
            if (auction.currentHighestBidder != address(0)) {
                _pendingReturns[auctionId][auction.currentHighestBidder] =
                    _pendingReturns[auctionId][auction.currentHighestBidder].add(auction.currentHighestBid);
            }
        }
    }


    function withdrawBid(uint256 auctionId) external nonReentrant {
        uint256 amount = _pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        _pendingReturns[auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit BidRefunded(auctionId, msg.sender, amount);
    }


    function getAuction(uint256 auctionId)
        external
        view
        auctionExists(auctionId)
        returns (Auction memory)
    {
        return _auctions[auctionId];
    }

    function getAuctionBids(uint256 auctionId)
        external
        view
        auctionExists(auctionId)
        returns (Bid[] memory)
    {
        return _auctionBids[auctionId];
    }

    function getUserAuctions(address user) external view returns (uint256[] memory) {
        return _userAuctions[user];
    }

    function getUserBids(address user) external view returns (uint256[] memory) {
        return _userBids[user];
    }

    function getPendingReturns(uint256 auctionId, address bidder)
        external
        view
        returns (uint256)
    {
        return _pendingReturns[auctionId][bidder];
    }

    function getNextAuctionId() external view returns (uint256) {
        return _nextAuctionId;
    }

    function isAuctionActive(uint256 auctionId)
        external
        view
        auctionExists(auctionId)
        returns (bool)
    {
        Auction storage auction = _auctions[auctionId];
        return auction.status == AuctionStatus.Active && block.timestamp < auction.endTime;
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
