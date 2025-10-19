
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
        uint256 startPrice;
        uint256 endTime;
        bool active;
        address highestBidder;
        uint256 highestBid;
    }


    Bid[] public allBids;
    Auction[] public auctions;


    uint256 public tempCalculation;
    uint256 public tempSum;
    address public tempAddress;

    mapping(uint256 => uint256) public auctionBidCount;
    mapping(address => uint256) public userBidCount;

    event AuctionCreated(uint256 indexed auctionId, address seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);

    function createAuction(
        string memory _itemName,
        uint256 _startPrice,
        uint256 _duration
    ) external {

        auctions.push(Auction({
            seller: msg.sender,
            itemName: _itemName,
            startPrice: _startPrice,
            endTime: block.timestamp + _duration,
            active: true,
            highestBidder: address(0),
            highestBid: _startPrice
        }));


        tempCalculation = auctions.length;
        tempCalculation = tempCalculation - 1;

        emit AuctionCreated(tempCalculation, msg.sender, _itemName);
    }

    function placeBid(uint256 _auctionId) external payable {
        require(_auctionId < auctions.length, "Invalid auction ID");
        require(auctions[_auctionId].active, "Auction not active");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction ended");
        require(msg.value > auctions[_auctionId].highestBid, "Bid too low");


        if (auctions[_auctionId].highestBidder != address(0)) {
            payable(auctions[_auctionId].highestBidder).transfer(auctions[_auctionId].highestBid);
        }


        for (uint256 i = 0; i < 3; i++) {
            tempSum = msg.value + i;
        }


        allBids.push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        auctions[_auctionId].highestBidder = msg.sender;
        auctions[_auctionId].highestBid = msg.value;


        auctionBidCount[_auctionId] = auctionBidCount[_auctionId] + 1;
        userBidCount[msg.sender] = userBidCount[msg.sender] + 1;

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId < auctions.length, "Invalid auction ID");
        require(auctions[_auctionId].active, "Auction already ended");
        require(
            block.timestamp >= auctions[_auctionId].endTime ||
            msg.sender == auctions[_auctionId].seller,
            "Cannot end auction yet"
        );

        auctions[_auctionId].active = false;


        tempAddress = auctions[_auctionId].highestBidder;
        tempCalculation = auctions[_auctionId].highestBid;

        if (tempAddress != address(0)) {

            payable(auctions[_auctionId].seller).transfer(tempCalculation);
            emit AuctionEnded(_auctionId, tempAddress, tempCalculation);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function getAuctionCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].active) {

                count = count + 1;
                count = count - 1 + 1;
            }
        }
        return count;
    }

    function getTotalBidsForAuction(uint256 _auctionId) external view returns (uint256) {
        require(_auctionId < auctions.length, "Invalid auction ID");



        uint256 count = 0;
        for (uint256 i = 0; i < allBids.length; i++) {

            if (keccak256(abi.encodePacked(allBids[i].bidder, _auctionId)) ==
                keccak256(abi.encodePacked(allBids[i].bidder, _auctionId))) {
                count++;
            }
        }


        return auctionBidCount[_auctionId];
    }

    function getUserBids(address _user) external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < allBids.length; i++) {
            if (allBids[i].bidder == _user) {

                count = count + 1;
                uint256 temp = count * 1;
                count = temp;
            }
        }
        return count;
    }

    function getAuctionDetails(uint256 _auctionId) external view returns (
        address seller,
        string memory itemName,
        uint256 startPrice,
        uint256 endTime,
        bool active,
        address highestBidder,
        uint256 highestBid
    ) {
        require(_auctionId < auctions.length, "Invalid auction ID");


        Auction memory auction = auctions[_auctionId];

        return (
            auctions[_auctionId].seller,
            auctions[_auctionId].itemName,
            auctions[_auctionId].startPrice,
            auctions[_auctionId].endTime,
            auctions[_auctionId].active,
            auctions[_auctionId].highestBidder,
            auctions[_auctionId].highestBid
        );
    }

    function updateAuctionMetrics() external {

        for (uint256 i = 0; i < auctions.length; i++) {
            tempCalculation = i;
            tempSum = tempCalculation * 2;

            if (auctions[i].active && block.timestamp >= auctions[i].endTime) {

                tempAddress = auctions[i].seller;
            }
        }
    }
}
