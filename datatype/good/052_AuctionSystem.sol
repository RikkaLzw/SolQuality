
pragma solidity ^0.8.0;

contract AuctionSystem {
    struct Auction {
        bytes32 auctionId;
        address payable seller;
        bytes32 itemName;
        bytes32 description;
        uint128 startingPrice;
        uint128 currentBid;
        address payable currentBidder;
        uint32 auctionEndTime;
        bool active;
        bool ended;
    }

    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => mapping(address => uint128)) public pendingReturns;

    bytes32[] public auctionIds;

    event AuctionCreated(
        bytes32 indexed auctionId,
        address indexed seller,
        bytes32 itemName,
        uint128 startingPrice,
        uint32 endTime
    );

    event BidPlaced(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint128 amount
    );

    event AuctionEnded(
        bytes32 indexed auctionId,
        address indexed winner,
        uint128 winningBid
    );

    event FundsWithdrawn(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint128 amount
    );

    modifier onlyActiveBefore(bytes32 _auctionId) {
        require(auctions[_auctionId].active, "Auction not active");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction ended");
        _;
    }

    modifier onlyAfterEnd(bytes32 _auctionId) {
        require(block.timestamp >= auctions[_auctionId].auctionEndTime, "Auction still ongoing");
        _;
    }

    modifier auctionExists(bytes32 _auctionId) {
        require(auctions[_auctionId].seller != address(0), "Auction does not exist");
        _;
    }

    function createAuction(
        bytes32 _itemName,
        bytes32 _description,
        uint128 _startingPrice,
        uint32 _duration
    ) external returns (bytes32) {
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        bytes32 auctionId = keccak256(abi.encodePacked(
            msg.sender,
            _itemName,
            block.timestamp,
            block.number
        ));

        require(auctions[auctionId].seller == address(0), "Auction ID already exists");

        uint32 endTime = uint32(block.timestamp) + _duration;

        auctions[auctionId] = Auction({
            auctionId: auctionId,
            seller: payable(msg.sender),
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: payable(address(0)),
            auctionEndTime: endTime,
            active: true,
            ended: false
        });

        auctionIds.push(auctionId);

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, endTime);

        return auctionId;
    }

    function placeBid(bytes32 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        onlyActiveBefore(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.currentBid, "Bid must be higher than current bid");
        require(msg.value >= auction.startingPrice, "Bid must meet starting price");

        if (auction.currentBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = uint128(msg.value);
        auction.currentBidder = payable(msg.sender);

        emit BidPlaced(_auctionId, msg.sender, uint128(msg.value));
    }

    function endAuction(bytes32 _auctionId)
        external
        auctionExists(_auctionId)
        onlyAfterEnd(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];
        require(auction.active, "Auction already ended");

        auction.active = false;
        auction.ended = true;

        if (auction.currentBidder != address(0)) {
            auction.seller.transfer(auction.currentBid);
        }

        emit AuctionEnded(_auctionId, auction.currentBidder, auction.currentBid);
    }

    function withdraw(bytes32 _auctionId) external auctionExists(_auctionId) {
        uint128 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }

    function getAuction(bytes32 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (
            address seller,
            bytes32 itemName,
            bytes32 description,
            uint128 startingPrice,
            uint128 currentBid,
            address currentBidder,
            uint32 auctionEndTime,
            bool active,
            bool ended
        )
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.auctionEndTime,
            auction.active,
            auction.ended
        );
    }

    function getActiveAuctions() external view returns (bytes32[] memory) {
        uint256 activeCount = 0;

        for (uint256 i = 0; i < auctionIds.length; i++) {
            if (auctions[auctionIds[i]].active) {
                activeCount++;
            }
        }

        bytes32[] memory activeAuctions = new bytes32[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < auctionIds.length; i++) {
            if (auctions[auctionIds[i]].active) {
                activeAuctions[index] = auctionIds[i];
                index++;
            }
        }

        return activeAuctions;
    }

    function getPendingReturn(bytes32 _auctionId, address _bidder)
        external
        view
        returns (uint128)
    {
        return pendingReturns[_auctionId][_bidder];
    }

    function getTotalAuctions() external view returns (uint256) {
        return auctionIds.length;
    }
}
