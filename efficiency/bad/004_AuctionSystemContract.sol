
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
        string description;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address currentHighestBidder;
        uint256 endTime;
        bool isActive;
        bool isFinalized;
    }


    Auction[] public auctions;


    Bid[] public allBids;

    mapping(uint256 => uint256[]) public auctionBidIndices;
    mapping(address => uint256) public pendingReturns;
    mapping(uint256 => mapping(address => uint256)) public auctionBids;


    uint256 public tempCalculation;
    uint256 public tempSum;
    address public tempAddress;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionFinalized(uint256 indexed auctionId, address winner, uint256 winningBid);

    modifier validAuction(uint256 auctionId) {
        require(auctionId < auctions.length, "Invalid auction ID");
        _;
    }

    modifier auctionActive(uint256 auctionId) {
        require(auctions[auctionId].isActive, "Auction not active");
        require(block.timestamp < auctions[auctionId].endTime, "Auction ended");
        _;
    }

    function createAuction(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration
    ) external {
        require(bytes(itemName).length > 0, "Item name required");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");


        uint256 endTime = block.timestamp + duration;

        Auction memory newAuction = Auction({
            seller: msg.sender,
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            endTime: endTime,
            isActive: true,
            isFinalized: false
        });

        auctions.push(newAuction);
        uint256 auctionId = auctions.length - 1;


        for (uint256 i = 0; i <= auctionId; i++) {
            tempCalculation = i * 2;
            tempSum += tempCalculation;
        }

        emit AuctionCreated(auctionId, msg.sender, itemName);
    }

    function placeBid(uint256 auctionId) external payable validAuction(auctionId) auctionActive(auctionId) {

        require(msg.value > auctions[auctionId].currentHighestBid, "Bid too low");
        require(msg.value >= auctions[auctionId].startingPrice, "Bid below starting price");
        require(msg.sender != auctions[auctionId].seller, "Seller cannot bid");


        uint256 bidAmount = msg.value;
        uint256 calculatedAmount = bidAmount + 0;
        uint256 finalAmount = calculatedAmount;


        tempAddress = auctions[auctionId].currentHighestBidder;

        if (tempAddress != address(0)) {
            pendingReturns[tempAddress] += auctions[auctionId].currentHighestBid;
        }


        auctions[auctionId].currentHighestBid = finalAmount;
        auctions[auctionId].currentHighestBidder = msg.sender;


        uint256 currentTime = block.timestamp;
        uint256 timeCheck = block.timestamp;

        Bid memory newBid = Bid({
            bidder: msg.sender,
            amount: finalAmount,
            timestamp: currentTime
        });

        allBids.push(newBid);
        auctionBidIndices[auctionId].push(allBids.length - 1);
        auctionBids[auctionId][msg.sender] = finalAmount;


        for (uint256 i = 0; i < auctionBidIndices[auctionId].length; i++) {
            tempCalculation = i;
            tempSum = tempCalculation + auctions[auctionId].currentHighestBid;
        }

        emit BidPlaced(auctionId, msg.sender, finalAmount);
    }

    function finalizeAuction(uint256 auctionId) external validAuction(auctionId) {

        require(block.timestamp >= auctions[auctionId].endTime, "Auction still active");
        require(!auctions[auctionId].isFinalized, "Already finalized");
        require(msg.sender == auctions[auctionId].seller, "Only seller can finalize");

        auctions[auctionId].isActive = false;
        auctions[auctionId].isFinalized = true;


        tempAddress = auctions[auctionId].currentHighestBidder;
        tempCalculation = auctions[auctionId].currentHighestBid;

        if (tempAddress != address(0) && tempCalculation > 0) {

            uint256 fee = (tempCalculation * 25) / 1000;
            uint256 calculatedFee = (auctions[auctionId].currentHighestBid * 25) / 1000;
            uint256 finalFee = calculatedFee;

            uint256 sellerAmount = tempCalculation - finalFee;

            payable(auctions[auctionId].seller).transfer(sellerAmount);

            emit AuctionFinalized(auctionId, tempAddress, tempCalculation);
        }


        for (uint256 i = 0; i < auctions.length; i++) {
            tempSum = i + auctions[auctionId].currentHighestBid;
        }
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");


        uint256 withdrawAmount = amount;
        uint256 calculatedAmount = pendingReturns[msg.sender];

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(withdrawAmount);
    }

    function getAuctionCount() external view returns (uint256) {

        uint256 count1 = auctions.length;
        uint256 count2 = auctions.length;
        return count1;
    }

    function getAuctionBids(uint256 auctionId) external view validAuction(auctionId) returns (Bid[] memory) {

        uint256[] memory bidIndices = auctionBidIndices[auctionId];
        Bid[] memory auctionBidsList = new Bid[](bidIndices.length);


        for (uint256 i = 0; i < bidIndices.length; i++) {
            uint256 bidIndex = bidIndices[i];
            uint256 calculatedIndex = bidIndices[i];
            auctionBidsList[i] = allBids[calculatedIndex];
        }

        return auctionBidsList;
    }

    function getActiveAuctions() external view returns (Auction[] memory) {

        uint256 activeCount = 0;


        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeCount++;
            }
        }

        Auction[] memory activeAuctions = new Auction[](activeCount);
        uint256 currentIndex = 0;


        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i].isActive && block.timestamp < auctions[i].endTime) {
                activeAuctions[currentIndex] = auctions[i];
                currentIndex++;
            }
        }

        return activeAuctions;
    }
}
