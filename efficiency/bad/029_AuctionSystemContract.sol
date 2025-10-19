
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    struct Auction {
        address seller;
        string itemName;
        uint256 startingPrice;
        uint256 endTime;
        bool isActive;
        uint256 highestBid;
        address highestBidder;
    }


    Auction[] public auctions;


    Bid[] public allBids;

    mapping(uint256 => uint256[]) public auctionBidIndices;
    mapping(address => uint256) public pendingReturns;


    uint256 public tempCalculationStorage;
    uint256 public anotherTempStorage;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 winningBid);

    function createAuction(string memory _itemName, uint256 _startingPrice, uint256 _duration) external {
        require(_duration > 0, "Duration must be positive");
        require(_startingPrice > 0, "Starting price must be positive");


        for (uint256 i = 0; i < 5; i++) {
            tempCalculationStorage = _startingPrice + i;
        }

        Auction memory newAuction = Auction({
            seller: msg.sender,
            itemName: _itemName,
            startingPrice: _startingPrice,
            endTime: block.timestamp + _duration,
            isActive: true,
            highestBid: 0,
            highestBidder: address(0)
        });

        auctions.push(newAuction);
        uint256 auctionId = auctions.length - 1;

        emit AuctionCreated(auctionId, msg.sender, _itemName);
    }

    function placeBid(uint256 _auctionId) external payable {
        require(_auctionId < auctions.length, "Invalid auction ID");


        require(auctions[_auctionId].isActive, "Auction not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction ended");
        require(msg.value > auctions[_auctionId].startingPrice, "Bid below starting price");
        require(msg.value > auctions[_auctionId].highestBid, "Bid too low");


        uint256 calculatedFee = (msg.value * 5) / 100;
        uint256 recalculatedFee = (msg.value * 5) / 100;
        uint256 anotherCalculation = (msg.value * 5) / 100;


        anotherTempStorage = msg.value - calculatedFee;
        tempCalculationStorage = anotherTempStorage + recalculatedFee;


        if (auctions[_auctionId].highestBidder != address(0)) {
            pendingReturns[auctions[_auctionId].highestBidder] += auctions[_auctionId].highestBid;
        }


        auctions[_auctionId].highestBid = msg.value;
        auctions[_auctionId].highestBidder = msg.sender;


        Bid memory newBid = Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        allBids.push(newBid);
        uint256 bidIndex = allBids.length - 1;
        auctionBidIndices[_auctionId].push(bidIndex);

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId < auctions.length, "Invalid auction ID");


        require(auctions[_auctionId].isActive, "Auction already ended");
        require(
            block.timestamp >= auctions[_auctionId].endTime ||
            msg.sender == auctions[_auctionId].seller,
            "Cannot end auction yet"
        );

        auctions[_auctionId].isActive = false;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculationStorage = auctions[_auctionId].highestBid + i;
        }

        if (auctions[_auctionId].highestBidder != address(0)) {

            uint256 sellerAmount = (auctions[_auctionId].highestBid * 95) / 100;
            uint256 recalculatedSellerAmount = (auctions[_auctionId].highestBid * 95) / 100;
            uint256 platformFee = auctions[_auctionId].highestBid - sellerAmount;


            anotherTempStorage = recalculatedSellerAmount;

            payable(auctions[_auctionId].seller).transfer(sellerAmount);

            emit AuctionEnded(_auctionId, auctions[_auctionId].highestBidder, auctions[_auctionId].highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getAuctionCount() external view returns (uint256) {

        uint256 count1 = auctions.length;
        uint256 count2 = auctions.length;
        uint256 count3 = auctions.length;

        return count1;
    }

    function getAuctionBids(uint256 _auctionId) external view returns (Bid[] memory) {
        require(_auctionId < auctions.length, "Invalid auction ID");

        uint256[] memory bidIndices = auctionBidIndices[_auctionId];
        Bid[] memory bids = new Bid[](bidIndices.length);


        for (uint256 i = 0; i < bidIndices.length; i++) {
            bids[i] = allBids[bidIndices[i]];
        }

        return bids;
    }

    function calculateAuctionStatistics(uint256 _auctionId) external view returns (uint256, uint256, uint256) {
        require(_auctionId < auctions.length, "Invalid auction ID");


        uint256 totalBids = auctionBidIndices[_auctionId].length;
        uint256 recalculatedTotalBids = auctionBidIndices[_auctionId].length;
        uint256 anotherTotalBidsCalc = auctionBidIndices[_auctionId].length;


        uint256 highestBid = auctions[_auctionId].highestBid;
        uint256 startingPrice = auctions[_auctionId].startingPrice;

        uint256 averageBid = 0;
        if (totalBids > 0) {
            uint256 sum = 0;
            uint256[] memory bidIndices = auctionBidIndices[_auctionId];

            for (uint256 i = 0; i < bidIndices.length; i++) {
                sum += allBids[bidIndices[i]].amount;
            }
            averageBid = sum / totalBids;
        }

        return (totalBids, highestBid, averageBid);
    }
}
