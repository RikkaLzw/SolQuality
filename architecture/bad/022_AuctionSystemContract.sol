
pragma solidity ^0.8.0;

contract AuctionSystemContract {


    address public owner;
    uint256 public totalAuctions;
    mapping(uint256 => address) public auctionCreators;
    mapping(uint256 => uint256) public auctionStartTimes;
    mapping(uint256 => uint256) public auctionEndTimes;
    mapping(uint256 => uint256) public startingPrices;
    mapping(uint256 => uint256) public currentHighestBids;
    mapping(uint256 => address) public currentHighestBidders;
    mapping(uint256 => string) public auctionTitles;
    mapping(uint256 => string) public auctionDescriptions;
    mapping(uint256 => bool) public auctionActive;
    mapping(uint256 => bool) public auctionFinalized;
    mapping(uint256 => mapping(address => uint256)) public bidderAmounts;
    mapping(address => uint256) public userBalances;

    event AuctionCreated(uint256 indexed auctionId, address indexed creator, string title, uint256 startingPrice);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 winningBid);
    event FundsWithdrawn(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
        totalAuctions = 0;
    }


    function createAuction(
        string memory title,
        string memory description,
        uint256 startingPrice,
        uint256 durationInHours
    ) public {

        require(startingPrice >= 1000000000000000, "Starting price too low");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        require(durationInHours >= 1 && durationInHours <= 168, "Duration must be 1-168 hours");

        uint256 auctionId = totalAuctions;
        totalAuctions++;

        auctionCreators[auctionId] = msg.sender;
        auctionTitles[auctionId] = title;
        auctionDescriptions[auctionId] = description;
        startingPrices[auctionId] = startingPrice;
        auctionStartTimes[auctionId] = block.timestamp;

        auctionEndTimes[auctionId] = block.timestamp + (durationInHours * 3600);
        currentHighestBids[auctionId] = startingPrice;
        currentHighestBidders[auctionId] = address(0);
        auctionActive[auctionId] = true;
        auctionFinalized[auctionId] = false;

        emit AuctionCreated(auctionId, msg.sender, title, startingPrice);
    }


    function placeBid(uint256 auctionId) public payable {

        require(auctionId < totalAuctions, "Auction does not exist");
        require(auctionActive[auctionId], "Auction is not active");
        require(block.timestamp < auctionEndTimes[auctionId], "Auction has ended");
        require(msg.sender != auctionCreators[auctionId], "Creator cannot bid on own auction");


        uint256 minimumBid = currentHighestBids[auctionId] + 10000000000000000;
        require(msg.value >= minimumBid, "Bid too low");


        if (currentHighestBidders[auctionId] != address(0)) {
            userBalances[currentHighestBidders[auctionId]] += currentHighestBids[auctionId];
        }

        currentHighestBids[auctionId] = msg.value;
        currentHighestBidders[auctionId] = msg.sender;
        bidderAmounts[auctionId][msg.sender] = msg.value;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }


    function endAuction(uint256 auctionId) public {

        require(auctionId < totalAuctions, "Auction does not exist");
        require(auctionActive[auctionId], "Auction is not active");
        require(block.timestamp >= auctionEndTimes[auctionId], "Auction has not ended yet");
        require(!auctionFinalized[auctionId], "Auction already finalized");

        auctionActive[auctionId] = false;
        auctionFinalized[auctionId] = true;

        if (currentHighestBidders[auctionId] != address(0)) {

            userBalances[auctionCreators[auctionId]] += currentHighestBids[auctionId];
            emit AuctionEnded(auctionId, currentHighestBidders[auctionId], currentHighestBids[auctionId]);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }


    function withdrawFunds() public {
        uint256 amount = userBalances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        userBalances[msg.sender] = 0;


        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function getAuctionInfo(uint256 auctionId) public view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 startTime,
        uint256 endTime,
        bool active,
        bool finalized
    ) {

        require(auctionId < totalAuctions, "Auction does not exist");

        return (
            auctionCreators[auctionId],
            auctionTitles[auctionId],
            auctionDescriptions[auctionId],
            startingPrices[auctionId],
            currentHighestBids[auctionId],
            currentHighestBidders[auctionId],
            auctionStartTimes[auctionId],
            auctionEndTimes[auctionId],
            auctionActive[auctionId],
            auctionFinalized[auctionId]
        );
    }


    function getUserBalance(address user) public view returns (uint256) {
        return userBalances[user];
    }


    function getUserBidInAuction(uint256 auctionId, address user) public view returns (uint256) {

        require(auctionId < totalAuctions, "Auction does not exist");
        return bidderAmounts[auctionId][user];
    }


    function isAuctionEnded(uint256 auctionId) public view returns (bool) {

        require(auctionId < totalAuctions, "Auction does not exist");
        return block.timestamp >= auctionEndTimes[auctionId];
    }


    function getActiveAuctionsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalAuctions; i++) {
            if (auctionActive[i] && block.timestamp < auctionEndTimes[i]) {
                count++;
            }
        }
        return count;
    }


    function emergencyStopAuction(uint256 auctionId) public {
        require(msg.sender == owner, "Only owner can emergency stop");

        require(auctionId < totalAuctions, "Auction does not exist");
        require(auctionActive[auctionId], "Auction is not active");

        auctionActive[auctionId] = false;


        if (currentHighestBidders[auctionId] != address(0)) {
            userBalances[currentHighestBidders[auctionId]] += currentHighestBids[auctionId];
            currentHighestBids[auctionId] = startingPrices[auctionId];
            currentHighestBidders[auctionId] = address(0);
        }
    }


    function batchEndExpiredAuctions() public {
        for (uint256 i = 0; i < totalAuctions; i++) {

            if (auctionActive[i] &&
                block.timestamp >= auctionEndTimes[i] &&
                !auctionFinalized[i]) {

                auctionActive[i] = false;
                auctionFinalized[i] = true;

                if (currentHighestBidders[i] != address(0)) {
                    userBalances[auctionCreators[i]] += currentHighestBids[i];
                    emit AuctionEnded(i, currentHighestBidders[i], currentHighestBids[i]);
                } else {
                    emit AuctionEnded(i, address(0), 0);
                }
            }
        }
    }


    function getAuctionTimeRemaining(uint256 auctionId) public view returns (uint256) {

        require(auctionId < totalAuctions, "Auction does not exist");

        if (block.timestamp >= auctionEndTimes[auctionId]) {
            return 0;
        }
        return auctionEndTimes[auctionId] - block.timestamp;
    }


    function changeOwner(address newOwner) public {
        require(msg.sender == owner, "Only current owner can change owner");
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
