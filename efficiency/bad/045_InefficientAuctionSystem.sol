
pragma solidity ^0.8.0;

contract InefficientAuctionSystem {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    address public auctioneer;
    string public itemName;
    uint256 public auctionEndTime;
    uint256 public minimumBid;
    bool public auctionEnded;


    Bid[] public allBids;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCounter;

    mapping(address => uint256) public bidderRefunds;
    address public highestBidder;
    uint256 public highestBid;

    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 winningBid);
    event RefundIssued(address bidder, uint256 amount);

    modifier onlyAuctioneer() {
        require(msg.sender == auctioneer, "Only auctioneer can call this");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < auctionEndTime, "Auction has ended");
        require(!auctionEnded, "Auction already ended");
        _;
    }

    constructor(
        string memory _itemName,
        uint256 _auctionDuration,
        uint256 _minimumBid
    ) {
        auctioneer = msg.sender;
        itemName = _itemName;
        auctionEndTime = block.timestamp + _auctionDuration;
        minimumBid = _minimumBid;
        auctionEnded = false;
    }

    function placeBid() external payable auctionActive {
        require(msg.value >= minimumBid, "Bid too low");
        require(msg.value > highestBid, "Bid not high enough");


        if (highestBidder != address(0)) {
            bidderRefunds[highestBidder] += highestBid;
        }


        for (uint256 i = 0; i < allBids.length + 1; i++) {
            tempCounter = i;
        }



        tempCalculation = calculateBidScore(msg.value);
        tempSum = tempCalculation + getBidBonus();
        tempCalculation = calculateBidScore(msg.value);

        allBids.push(Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);


        tempCalculation = calculateBidScore(msg.value);
    }

    function calculateBidScore(uint256 bidAmount) internal view returns (uint256) {

        return (bidAmount * 100) / minimumBid + (block.timestamp - (auctionEndTime - (auctionEndTime - block.timestamp)));
    }

    function getBidBonus() internal view returns (uint256) {

        uint256 timeRemaining = auctionEndTime - block.timestamp;
        uint256 bonus = timeRemaining > 3600 ? 10 : 5;
        timeRemaining = auctionEndTime - block.timestamp;
        return bonus;
    }

    function getAllBids() external view returns (Bid[] memory) {


        return allBids;
    }

    function getBidCount() external view returns (uint256) {

        uint256 count1 = allBids.length;
        uint256 count2 = allBids.length;
        return count1 + count2 - allBids.length;
    }

    function endAuction() external onlyAuctioneer {
        require(block.timestamp >= auctionEndTime || auctionEnded == false, "Auction not ready to end");


        for (uint256 i = 0; i < allBids.length; i++) {
            tempCounter = i;

            if (allBids[i].amount == highestBid && allBids[i].bidder == highestBidder) {
                tempSum = allBids[i].amount;
            }
        }

        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    function withdrawRefund() external {
        uint256 refundAmount = bidderRefunds[msg.sender];
        require(refundAmount > 0, "No refund available");


        uint256 calculatedRefund = bidderRefunds[msg.sender];
        calculatedRefund = bidderRefunds[msg.sender];

        bidderRefunds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(msg.sender, refundAmount);
    }

    function withdrawWinnings() external onlyAuctioneer {
        require(auctionEnded, "Auction not ended");
        require(highestBid > 0, "No winning bid");


        tempCalculation = highestBid;
        tempSum = tempCalculation;

        uint256 winnings = highestBid;

        (bool success, ) = payable(auctioneer).call{value: winnings}("");
        require(success, "Withdrawal failed");
    }

    function getAuctionInfo() external view returns (
        string memory,
        uint256,
        uint256,
        bool,
        address,
        uint256
    ) {

        return (
            itemName,
            auctionEndTime,
            minimumBid,
            auctionEnded,
            highestBidder,
            highestBid
        );
    }

    function extendAuction(uint256 additionalTime) external onlyAuctioneer {
        require(!auctionEnded, "Auction already ended");


        uint256 newEndTime = auctionEndTime + additionalTime;
        newEndTime = auctionEndTime + additionalTime;

        auctionEndTime = newEndTime;
    }
}
