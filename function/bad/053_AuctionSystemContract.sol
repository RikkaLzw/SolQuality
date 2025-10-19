
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Auction {
        address payable seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address payable highestBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    struct Bidder {
        uint256 totalBids;
        uint256 successfulBids;
        bool isRegistered;
        uint256 reputation;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => Bidder) public bidders;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256[]) public userAuctions;

    uint256 public auctionCounter;
    address public owner;
    uint256 public platformFee = 25;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createAuctionAndRegisterUser(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        bool autoRegister,
        uint256 initialReputation,
        string memory additionalInfo
    ) public {

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: payable(msg.sender),
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            currentBid: startingPrice,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            ended: false,
            exists: true
        });

        userAuctions[msg.sender].push(auctionCounter);


        if (autoRegister && !bidders[msg.sender].isRegistered) {
            bidders[msg.sender] = Bidder({
                totalBids: 0,
                successfulBids: 0,
                isRegistered: true,
                reputation: initialReputation
            });
        }


        if (bytes(additionalInfo).length > 0) {

        }

        emit AuctionCreated(auctionCounter, msg.sender, itemName);
    }


    function calculateFeeAndValidation(uint256 amount, address bidder) public view returns (uint256) {
        require(bidders[bidder].isRegistered, "Bidder not registered");
        return (amount * platformFee) / 1000;
    }



    function placeBidWithComplexLogic(uint256 auctionId) public payable returns (bool, uint256, address) {
        require(auctions[auctionId].exists, "Auction does not exist");
        require(!auctions[auctionId].ended, "Auction ended");
        require(block.timestamp < auctions[auctionId].endTime, "Auction expired");
        require(msg.value > auctions[auctionId].currentBid, "Bid too low");


        if (bidders[msg.sender].isRegistered) {
            if (bidders[msg.sender].reputation > 50) {
                if (msg.value > auctions[auctionId].currentBid * 110 / 100) {
                    if (auctions[auctionId].highestBidder != address(0)) {
                        if (bids[auctionId][auctions[auctionId].highestBidder] > 0) {

                            address payable previousBidder = auctions[auctionId].highestBidder;
                            uint256 previousBid = bids[auctionId][previousBidder];
                            bids[auctionId][previousBidder] = 0;
                            previousBidder.transfer(previousBid);


                            if (bidders[previousBidder].totalBids > 0) {
                                if (bidders[previousBidder].reputation > 10) {
                                    bidders[previousBidder].reputation -= 1;
                                }
                            }
                        }
                    }


                    auctions[auctionId].currentBid = msg.value;
                    auctions[auctionId].highestBidder = payable(msg.sender);
                    bids[auctionId][msg.sender] = msg.value;
                    bidders[msg.sender].totalBids++;


                    if (msg.value > auctions[auctionId].startingPrice * 150 / 100) {
                        if (bidders[msg.sender].reputation < 100) {
                            bidders[msg.sender].reputation += 2;
                        }
                    } else {
                        if (bidders[msg.sender].reputation < 100) {
                            bidders[msg.sender].reputation += 1;
                        }
                    }

                    emit BidPlaced(auctionId, msg.sender, msg.value);
                    return (true, msg.value, msg.sender);
                } else {
                    revert("Bid increment too small");
                }
            } else {
                revert("Reputation too low");
            }
        } else {
            revert("User not registered");
        }
    }

    function endAuction(uint256 auctionId) public {
        require(auctions[auctionId].exists, "Auction does not exist");
        require(!auctions[auctionId].ended, "Already ended");
        require(
            block.timestamp >= auctions[auctionId].endTime ||
            msg.sender == auctions[auctionId].seller,
            "Cannot end yet"
        );

        auctions[auctionId].ended = true;

        if (auctions[auctionId].highestBidder != address(0)) {
            uint256 fee = calculateFeeAndValidation(auctions[auctionId].currentBid, auctions[auctionId].highestBidder);
            uint256 sellerAmount = auctions[auctionId].currentBid - fee;

            auctions[auctionId].seller.transfer(sellerAmount);
            payable(owner).transfer(fee);

            bidders[auctions[auctionId].highestBidder].successfulBids++;

            emit AuctionEnded(auctionId, auctions[auctionId].highestBidder, auctions[auctionId].currentBid);
        }
    }

    function registerBidder() public {
        require(!bidders[msg.sender].isRegistered, "Already registered");
        bidders[msg.sender] = Bidder({
            totalBids: 0,
            successfulBids: 0,
            isRegistered: true,
            reputation: 50
        });
    }

    function getAuctionDetails(uint256 auctionId) public view returns (
        address seller,
        string memory itemName,
        uint256 currentBid,
        address highestBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction memory auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.currentBid,
            auction.highestBidder,
            auction.endTime,
            auction.ended
        );
    }

    function getUserAuctions(address user) public view returns (uint256[] memory) {
        return userAuctions[user];
    }

    function updatePlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 100, "Fee too high");
        platformFee = newFee;
    }

    function withdrawEmergency() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
