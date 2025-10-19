
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
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    uint256 public auctionCounter;

    error Error1();
    error Error2();
    error Error3();

    event AuctionCreated(uint256 auctionId, string itemName, uint256 startingPrice);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);

    function createAuction(string memory _itemName, uint256 _startingPrice, uint256 _duration) external returns (uint256) {
        require(_startingPrice > 0);
        require(_duration > 0);

        uint256 auctionId = auctionCounter++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: _itemName,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false
        });

        emit AuctionCreated(auctionId, _itemName, _startingPrice);
        return auctionId;
    }

    function placeBid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        require(block.timestamp < auction.endTime);
        require(msg.value > auction.currentBid);
        require(msg.value >= auction.startingPrice);
        require(!auction.ended);

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

        require(block.timestamp >= auction.endTime);
        require(!auction.ended);
        require(msg.sender == auction.seller);

        auction.ended = true;

        if (auction.currentBidder != address(0)) {
            payable(auction.seller).transfer(auction.currentBid);
        }
    }

    function getAuctionInfo(uint256 _auctionId) external view returns (
        address seller,
        string memory itemName,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction storage auction = auctions[_auctionId];
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

    function cancelAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        if (msg.sender != auction.seller) {
            revert Error1();
        }
        if (auction.ended) {
            revert Error2();
        }
        if (auction.currentBidder != address(0)) {
            revert Error3();
        }

        auction.ended = true;
    }

    function extendAuction(uint256 _auctionId, uint256 _additionalTime) external {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender == auction.seller);
        require(!auction.ended);
        require(block.timestamp < auction.endTime);

        auction.endTime += _additionalTime;
    }
}
