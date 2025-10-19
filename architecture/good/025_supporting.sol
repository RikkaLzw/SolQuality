
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";


contract AuctionSystem is ReentrancyGuard, Ownable, Pausable {


    uint256 public constant MIN_BID_INCREMENT = 0.01 ether;
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant MAX_AUCTION_DURATION = 30 days;
    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant BASIS_POINTS = 10000;


    enum AuctionType { English, Dutch, Reserve }
    enum AuctionStatus { Active, Ended, Cancelled }


    struct Auction {
        uint256 id;
        address seller;
        string itemName;
        string description;
        AuctionType auctionType;
        AuctionStatus status;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 currentPrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 totalBids;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private _auctionIdCounter;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => uint256) public userEarnings;

    uint256 public platformEarnings;


    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        AuctionType auctionType,
        uint256 startPrice,
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

    event FundsWithdrawn(address indexed user, uint256 amount);


    modifier validAuction(uint256 _auctionId) {
        require(_auctionId < _auctionIdCounter, "Auction does not exist");
        _;
    }

    modifier onlyActiveBidding(uint256 _auctionId) {
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        _;
    }

    modifier onlySeller(uint256 _auctionId) {
        require(auctions[_auctionId].seller == msg.sender, "Only seller allowed");
        _;
    }

    modifier validDuration(uint256 _duration) {
        require(_duration >= MIN_AUCTION_DURATION, "Duration too short");
        require(_duration <= MAX_AUCTION_DURATION, "Duration too long");
        _;
    }

    constructor() Ownable(msg.sender) {}


    function createAuction(
        string memory _itemName,
        string memory _description,
        AuctionType _auctionType,
        uint256 _startPrice,
        uint256 _reservePrice,
        uint256 _duration
    )
        external
        whenNotPaused
        validDuration(_duration)
        returns (uint256)
    {
        require(bytes(_itemName).length > 0, "Item name required");
        require(_startPrice > 0, "Start price must be positive");

        if (_auctionType == AuctionType.Reserve) {
            require(_reservePrice >= _startPrice, "Reserve price too low");
        }

        uint256 auctionId = _auctionIdCounter++;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionId] = Auction({
            id: auctionId,
            seller: msg.sender,
            itemName: _itemName,
            description: _description,
            auctionType: _auctionType,
            status: AuctionStatus.Active,
            startPrice: _startPrice,
            reservePrice: _reservePrice,
            currentPrice: _startPrice,
            startTime: block.timestamp,
            endTime: endTime,
            highestBidder: address(0),
            totalBids: 0
        });

        userAuctions[msg.sender].push(auctionId);

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _itemName,
            _auctionType,
            _startPrice,
            endTime
        );

        return auctionId;
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        nonReentrant
        whenNotPaused
        validAuction(_auctionId)
        onlyActiveBidding(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender != auction.seller, "Seller cannot bid");
        require(msg.value > 0, "Bid must be positive");

        uint256 minBidAmount = _calculateMinBidAmount(auction);
        require(msg.value >= minBidAmount, "Bid too low");


        if (auction.highestBidder != address(0)) {
            pendingReturns[_auctionId][auction.highestBidder] += auction.currentPrice;
        }


        auction.currentPrice = msg.value;
        auction.highestBidder = msg.sender;
        auction.totalBids++;


        auctionBids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        if (auction.endTime - block.timestamp < 10 minutes) {
            auction.endTime += 10 minutes;
        }

        emit BidPlaced(_auctionId, msg.sender, msg.value, block.timestamp);
    }


    function endAuction(uint256 _auctionId)
        external
        nonReentrant
        validAuction(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(
            block.timestamp > auction.endTime || msg.sender == auction.seller,
            "Cannot end auction yet"
        );

        auction.status = AuctionStatus.Ended;

        if (auction.highestBidder != address(0) && _isReserveMet(auction)) {

            uint256 platformFee = _calculatePlatformFee(auction.currentPrice);
            uint256 sellerAmount = auction.currentPrice - platformFee;

            platformEarnings += platformFee;
            userEarnings[auction.seller] += sellerAmount;

            emit AuctionEnded(_auctionId, auction.highestBidder, auction.currentPrice);
        } else {

            if (auction.highestBidder != address(0)) {
                pendingReturns[_auctionId][auction.highestBidder] += auction.currentPrice;
            }
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }


    function cancelAuction(uint256 _auctionId)
        external
        validAuction(_auctionId)
        onlySeller(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(auction.totalBids == 0, "Cannot cancel with existing bids");

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(_auctionId, msg.sender);
    }


    function withdraw(uint256 _auctionId) external nonReentrant {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function withdrawEarnings() external nonReentrant {
        uint256 amount = userEarnings[msg.sender];
        require(amount > 0, "No earnings to withdraw");

        userEarnings[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        uint256 amount = platformEarnings;
        require(amount > 0, "No fees to withdraw");

        platformEarnings = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner(), amount);
    }


    function getAuction(uint256 _auctionId)
        external
        view
        validAuction(_auctionId)
        returns (Auction memory)
    {
        return auctions[_auctionId];
    }

    function getAuctionBids(uint256 _auctionId)
        external
        view
        validAuction(_auctionId)
        returns (Bid[] memory)
    {
        return auctionBids[_auctionId];
    }

    function getUserAuctions(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userAuctions[_user];
    }

    function getPendingReturn(uint256 _auctionId, address _bidder)
        external
        view
        returns (uint256)
    {
        return pendingReturns[_auctionId][_bidder];
    }

    function getTotalAuctions() external view returns (uint256) {
        return _auctionIdCounter;
    }


    function _calculateMinBidAmount(Auction memory _auction)
        internal
        pure
        returns (uint256)
    {
        if (_auction.highestBidder == address(0)) {
            return _auction.startPrice;
        }
        return _auction.currentPrice + MIN_BID_INCREMENT;
    }

    function _calculatePlatformFee(uint256 _amount)
        internal
        pure
        returns (uint256)
    {
        return (_amount * PLATFORM_FEE_RATE) / BASIS_POINTS;
    }

    function _isReserveMet(Auction memory _auction)
        internal
        pure
        returns (bool)
    {
        if (_auction.auctionType != AuctionType.Reserve) {
            return true;
        }
        return _auction.currentPrice >= _auction.reservePrice;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
