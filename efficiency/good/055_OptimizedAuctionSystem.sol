
pragma solidity ^0.8.0;

contract OptimizedAuctionSystem {
    struct Auction {
        address payable seller;
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    struct Bidder {
        uint256 totalBids;
        uint256 pendingReturns;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => Bidder) public bidders;
    mapping(uint256 => mapping(address => uint256)) public auctionBids;

    uint256 public auctionCounter;
    uint256 private constant MIN_BID_INCREMENT = 0.01 ether;
    uint256 private constant MIN_AUCTION_DURATION = 1 hours;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, uint256 startingPrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event FundsWithdrawn(address indexed bidder, uint256 amount);

    error AuctionNotExists();
    error AuctionEnded();
    error BidTooLow();
    error AuctionNotEndedYet();
    error NoFundsToWithdraw();
    error TransferFailed();
    error InvalidDuration();
    error InvalidStartingPrice();

    modifier auctionExists(uint256 _auctionId) {
        if (!auctions[_auctionId].exists) revert AuctionNotExists();
        _;
    }

    modifier auctionActive(uint256 _auctionId) {
        Auction storage auction = auctions[_auctionId];
        if (auction.ended || block.timestamp >= auction.endTime) revert AuctionEnded();
        _;
    }

    function createAuction(uint256 _startingPrice, uint256 _duration) external returns (uint256) {
        if (_startingPrice == 0) revert InvalidStartingPrice();
        if (_duration < MIN_AUCTION_DURATION) revert InvalidDuration();

        uint256 auctionId = ++auctionCounter;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)),
            endTime: endTime,
            ended: false,
            exists: true
        });

        emit AuctionCreated(auctionId, msg.sender, _startingPrice, endTime);
        return auctionId;
    }

    function placeBid(uint256 _auctionId) external payable
        auctionExists(_auctionId)
        auctionActive(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        uint256 totalBid = auctionBids[_auctionId][msg.sender] + msg.value;

        uint256 minRequiredBid = auction.highestBid == 0 ?
            auction.startingPrice :
            auction.highestBid + MIN_BID_INCREMENT;

        if (totalBid < minRequiredBid) revert BidTooLow();


        auctionBids[_auctionId][msg.sender] = totalBid;


        if (auction.highestBidder != address(0)) {
            bidders[auction.highestBidder].pendingReturns += auction.highestBid;
        }


        auction.highestBid = totalBid;
        auction.highestBidder = payable(msg.sender);


        bidders[msg.sender].totalBids++;

        emit BidPlaced(_auctionId, msg.sender, totalBid);
    }

    function endAuction(uint256 _auctionId) external auctionExists(_auctionId) {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp < auction.endTime && msg.sender != auction.seller) {
            revert AuctionNotEndedYet();
        }
        if (auction.ended) revert AuctionEnded();

        auction.ended = true;

        if (auction.highestBidder != address(0)) {

            (bool success, ) = auction.seller.call{value: auction.highestBid}("");
            if (!success) revert TransferFailed();

            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdraw() external {
        uint256 amount = bidders[msg.sender].pendingReturns;
        if (amount == 0) revert NoFundsToWithdraw();


        bidders[msg.sender].pendingReturns = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {

            bidders[msg.sender].pendingReturns = amount;
            revert TransferFailed();
        }

        emit FundsWithdrawn(msg.sender, amount);
    }

    function getAuctionDetails(uint256 _auctionId) external view
        auctionExists(_auctionId)
        returns (
            address seller,
            uint256 startingPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 endTime,
            bool ended,
            bool isActive
        )
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.endTime,
            auction.ended,
            !auction.ended && block.timestamp < auction.endTime
        );
    }

    function getBidderInfo(address _bidder) external view returns (uint256 totalBids, uint256 pendingReturns) {
        Bidder storage bidder = bidders[_bidder];
        return (bidder.totalBids, bidder.pendingReturns);
    }

    function getUserBidForAuction(uint256 _auctionId, address _user) external view returns (uint256) {
        return auctionBids[_auctionId][_user];
    }

    function getActiveAuctionsCount() external view returns (uint256 count) {
        uint256 currentTime = block.timestamp;
        for (uint256 i = 1; i <= auctionCounter; i++) {
            if (auctions[i].exists && !auctions[i].ended && currentTime < auctions[i].endTime) {
                count++;
            }
        }
    }
}
