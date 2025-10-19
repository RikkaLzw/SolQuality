
pragma solidity ^0.8.0;

contract AuctionSystemContract {


    address public owner;
    uint256 public totalAuctions;
    mapping(uint256 => address) public auctionCreators;
    mapping(uint256 => string) public auctionItems;
    mapping(uint256 => uint256) public startingPrices;
    mapping(uint256 => uint256) public currentHighestBids;
    mapping(uint256 => address) public currentHighestBidders;
    mapping(uint256 => uint256) public auctionEndTimes;
    mapping(uint256 => bool) public auctionEnded;
    mapping(uint256 => bool) public auctionCanceled;
    mapping(uint256 => mapping(address => uint256)) public bidderAmounts;
    mapping(uint256 => address[]) public biddersList;
    mapping(address => uint256) public userBalances;

    event AuctionCreated(uint256 auctionId, string item, uint256 startingPrice, uint256 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 winningBid);
    event AuctionCanceled(uint256 auctionId);
    event FundsWithdrawn(address user, uint256 amount);

    constructor() {
        owner = msg.sender;
        totalAuctions = 0;
    }


    function createAuction(string memory item, uint256 startingPrice, uint256 duration) public {

        require(duration >= 3600, "Duration must be at least 1 hour");
        require(startingPrice > 0, "Starting price must be greater than 0");
        require(bytes(item).length > 0, "Item description cannot be empty");

        totalAuctions++;
        uint256 auctionId = totalAuctions;

        auctionCreators[auctionId] = msg.sender;
        auctionItems[auctionId] = item;
        startingPrices[auctionId] = startingPrice;
        currentHighestBids[auctionId] = startingPrice;
        currentHighestBidders[auctionId] = address(0);

        auctionEndTimes[auctionId] = block.timestamp + duration;
        auctionEnded[auctionId] = false;
        auctionCanceled[auctionId] = false;

        emit AuctionCreated(auctionId, item, startingPrice, auctionEndTimes[auctionId]);
    }


    function placeBid(uint256 auctionId) public payable {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");
        require(!auctionEnded[auctionId], "Auction has ended");
        require(!auctionCanceled[auctionId], "Auction has been canceled");
        require(block.timestamp < auctionEndTimes[auctionId], "Auction time has expired");
        require(msg.sender != auctionCreators[auctionId], "Creator cannot bid on own auction");


        uint256 minimumBid = currentHighestBids[auctionId] + 1000000000000000;
        require(msg.value >= minimumBid, "Bid must be higher than current highest bid");


        if (bidderAmounts[auctionId][msg.sender] > 0) {
            userBalances[msg.sender] += bidderAmounts[auctionId][msg.sender];
        } else {
            biddersList[auctionId].push(msg.sender);
        }


        if (currentHighestBidders[auctionId] != address(0)) {
            userBalances[currentHighestBidders[auctionId]] += currentHighestBids[auctionId];
        }

        bidderAmounts[auctionId][msg.sender] = msg.value;
        currentHighestBids[auctionId] = msg.value;
        currentHighestBidders[auctionId] = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }


    function endAuction(uint256 auctionId) public {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");
        require(!auctionEnded[auctionId], "Auction has already ended");
        require(!auctionCanceled[auctionId], "Auction has been canceled");
        require(block.timestamp >= auctionEndTimes[auctionId], "Auction is still active");

        auctionEnded[auctionId] = true;

        if (currentHighestBidders[auctionId] != address(0)) {

            userBalances[auctionCreators[auctionId]] += currentHighestBids[auctionId];
            emit AuctionEnded(auctionId, currentHighestBidders[auctionId], currentHighestBids[auctionId]);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }


    function cancelAuction(uint256 auctionId) public {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");
        require(msg.sender == auctionCreators[auctionId], "Only creator can cancel auction");
        require(!auctionEnded[auctionId], "Cannot cancel ended auction");
        require(!auctionCanceled[auctionId], "Auction already canceled");

        auctionCanceled[auctionId] = true;


        for (uint256 i = 0; i < biddersList[auctionId].length; i++) {
            address bidder = biddersList[auctionId][i];
            if (bidderAmounts[auctionId][bidder] > 0) {
                userBalances[bidder] += bidderAmounts[auctionId][bidder];
                bidderAmounts[auctionId][bidder] = 0;
            }
        }

        emit AuctionCanceled(auctionId);
    }


    function withdrawFunds() public {
        uint256 amount = userBalances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        userBalances[msg.sender] = 0;


        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function emergencyWithdraw(address user) public {
        require(msg.sender == owner, "Only owner can perform emergency withdraw");

        uint256 amount = userBalances[user];
        require(amount > 0, "No funds to withdraw for user");

        userBalances[user] = 0;


        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(user, amount);
    }


    function getAuctionDetails(uint256 auctionId) public view returns (
        address creator,
        string memory item,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended,
        bool canceled
    ) {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");

        return (
            auctionCreators[auctionId],
            auctionItems[auctionId],
            startingPrices[auctionId],
            currentHighestBids[auctionId],
            currentHighestBidders[auctionId],
            auctionEndTimes[auctionId],
            auctionEnded[auctionId],
            auctionCanceled[auctionId]
        );
    }


    function getUserBidAmount(uint256 auctionId, address user) public view returns (uint256) {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");
        return bidderAmounts[auctionId][user];
    }


    function getAuctionBidders(uint256 auctionId) public view returns (address[] memory) {

        require(auctionId > 0 && auctionId <= totalAuctions, "Invalid auction ID");
        return biddersList[auctionId];
    }


    function canEndAuction(uint256 auctionId) public view returns (bool) {

        if (auctionId == 0 || auctionId > totalAuctions) {
            return false;
        }
        if (auctionEnded[auctionId] || auctionCanceled[auctionId]) {
            return false;
        }
        return block.timestamp >= auctionEndTimes[auctionId];
    }


    function getContractBalance() public view returns (uint256) {
        require(msg.sender == owner, "Only owner can view contract balance");
        return address(this).balance;
    }


    function changeOwner(address newOwner) public {
        require(msg.sender == owner, "Only current owner can change owner");
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }


    function batchEndExpiredAuctions(uint256[] memory auctionIds) public {
        for (uint256 i = 0; i < auctionIds.length; i++) {
            uint256 auctionId = auctionIds[i];


            if (auctionId > 0 && auctionId <= totalAuctions &&
                !auctionEnded[auctionId] &&
                !auctionCanceled[auctionId] &&
                block.timestamp >= auctionEndTimes[auctionId]) {

                auctionEnded[auctionId] = true;

                if (currentHighestBidders[auctionId] != address(0)) {
                    userBalances[auctionCreators[auctionId]] += currentHighestBids[auctionId];
                    emit AuctionEnded(auctionId, currentHighestBidders[auctionId], currentHighestBids[auctionId]);
                } else {
                    emit AuctionEnded(auctionId, address(0), 0);
                }
            }
        }
    }


    function getActiveAuctionsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (!auctionEnded[i] && !auctionCanceled[i] && block.timestamp < auctionEndTimes[i]) {
                count++;
            }
        }
        return count;
    }


    function getEndedAuctionsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i <= totalAuctions; i++) {
            if (auctionEnded[i]) {
                count++;
            }
        }
        return count;
    }


    receive() external payable {}


    fallback() external payable {}
}
