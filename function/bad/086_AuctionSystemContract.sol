
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Auction {
        address seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        bool active;
        bool ended;
    }

    struct Bidder {
        address bidderAddress;
        uint256 totalBids;
        uint256 totalAmount;
        bool isRegistered;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => Bidder) public bidders;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256[]) public userAuctions;

    uint256 public auctionCounter;
    address public owner;
    uint256 public platformFee = 25;

    event AuctionCreated(uint256 auctionId, address seller, string itemName);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 finalPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }



    function createAuctionAndRegisterBidder(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        address bidderToRegister,
        bool shouldRegisterSeller,
        uint256 sellerInitialBidCount
    ) public returns (bool) {

        require(startingPrice > 0, "Starting price must be positive");
        require(duration > 0, "Duration must be positive");

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: block.timestamp + duration,
            active: true,
            ended: false
        });

        userAuctions[msg.sender].push(auctionCounter);


        if (bidderToRegister != address(0)) {
            bidders[bidderToRegister] = Bidder({
                bidderAddress: bidderToRegister,
                totalBids: 0,
                totalAmount: 0,
                isRegistered: true
            });
        }


        if (shouldRegisterSeller) {
            bidders[msg.sender] = Bidder({
                bidderAddress: msg.sender,
                totalBids: sellerInitialBidCount,
                totalAmount: 0,
                isRegistered: true
            });
        }

        emit AuctionCreated(auctionCounter, msg.sender, itemName);
        return true;
    }


    function placeBidWithComplexLogic(uint256 auctionId, uint256 bidAmount) public payable {

        require(auctions[auctionId].active, "Auction not active");
        require(block.timestamp < auctions[auctionId].endTime, "Auction ended");
        require(msg.value == bidAmount, "Sent value must match bid amount");

        if (bidAmount > auctions[auctionId].currentBid) {
            if (auctions[auctionId].currentBidder != address(0)) {
                if (bids[auctionId][auctions[auctionId].currentBidder] > 0) {
                    if (auctions[auctionId].currentBid > 0) {
                        payable(auctions[auctionId].currentBidder).transfer(auctions[auctionId].currentBid);
                    }
                }
            }

            auctions[auctionId].currentBid = bidAmount;
            auctions[auctionId].currentBidder = msg.sender;
            bids[auctionId][msg.sender] = bidAmount;

            if (!bidders[msg.sender].isRegistered) {
                bidders[msg.sender] = Bidder({
                    bidderAddress: msg.sender,
                    totalBids: 1,
                    totalAmount: bidAmount,
                    isRegistered: true
                });
            } else {
                bidders[msg.sender].totalBids++;
                bidders[msg.sender].totalAmount += bidAmount;
            }

            emit BidPlaced(auctionId, msg.sender, bidAmount);
        } else {
            revert("Bid too low");
        }
    }


    function calculatePlatformFee(uint256 amount) public pure returns (uint256) {
        return (amount * 25) / 1000;
    }


    function validateAuctionState(uint256 auctionId) public view returns (bool) {
        return auctions[auctionId].active && !auctions[auctionId].ended;
    }

    function endAuction(uint256 auctionId) public {
        require(auctions[auctionId].active, "Auction not active");
        require(
            block.timestamp >= auctions[auctionId].endTime ||
            msg.sender == auctions[auctionId].seller ||
            msg.sender == owner,
            "Cannot end auction yet"
        );

        auctions[auctionId].active = false;
        auctions[auctionId].ended = true;

        if (auctions[auctionId].currentBidder != address(0)) {
            uint256 fee = calculatePlatformFee(auctions[auctionId].currentBid);
            uint256 sellerAmount = auctions[auctionId].currentBid - fee;

            payable(auctions[auctionId].seller).transfer(sellerAmount);
            payable(owner).transfer(fee);

            emit AuctionEnded(auctionId, auctions[auctionId].currentBidder, auctions[auctionId].currentBid);
        } else {
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }

    function getAuctionDetails(uint256 auctionId) public view returns (
        address seller,
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool active
    ) {
        Auction memory auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.active
        );
    }

    function getUserAuctions(address user) public view returns (uint256[] memory) {
        return userAuctions[user];
    }

    function getBidderInfo(address bidderAddr) public view returns (
        address bidderAddress,
        uint256 totalBids,
        uint256 totalAmount,
        bool isRegistered
    ) {
        Bidder memory bidder = bidders[bidderAddr];
        return (bidder.bidderAddress, bidder.totalBids, bidder.totalAmount, bidder.isRegistered);
    }

    function setPlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 100, "Fee too high");
        platformFee = newFee;
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
