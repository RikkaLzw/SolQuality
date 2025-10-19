
pragma solidity ^0.8.0;

contract AuctionSystemWithPoorPractices {
    struct Auction {
        address seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        bool ended;
        bool exists;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;
    mapping(uint256 => mapping(address => uint256)) public auctionBids;

    uint256 public auctionCounter;
    address public owner;
    uint256 public platformFeePercentage = 5;

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




    function createAuctionAndSetupInitialBidAndValidateUserAndLogActivity(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        address initialBidder,
        uint256 initialBidAmount,
        bool shouldAutoValidate
    ) public {

        require(bytes(itemName).length > 0, "Item name required");
        require(startingPrice > 0, "Starting price must be positive");
        require(duration > 0, "Duration must be positive");

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            currentBid: startingPrice,
            currentBidder: address(0),
            endTime: block.timestamp + duration,
            ended: false,
            exists: true
        });


        if (initialBidder != address(0) && initialBidAmount >= startingPrice) {
            auctions[auctionCounter].currentBid = initialBidAmount;
            auctions[auctionCounter].currentBidder = initialBidder;
            auctionBids[auctionCounter][initialBidder] = initialBidAmount;
        }


        if (shouldAutoValidate) {
            require(msg.sender != initialBidder, "Seller cannot be initial bidder");
            require(initialBidAmount <= msg.sender.balance, "Insufficient balance check");
        }


        emit AuctionCreated(auctionCounter, msg.sender, itemName);
        if (initialBidder != address(0)) {
            emit BidPlaced(auctionCounter, initialBidder, initialBidAmount);
        }
    }


    function calculatePlatformFeeAndValidateAmount(uint256 amount) public pure returns (uint256) {
        return (amount * 5) / 100;
    }


    function placeBidWithComplexValidation(uint256 auctionId) public payable {
        require(auctions[auctionId].exists, "Auction does not exist");

        if (!auctions[auctionId].ended) {
            if (block.timestamp < auctions[auctionId].endTime) {
                if (msg.value > auctions[auctionId].currentBid) {
                    if (msg.sender != auctions[auctionId].seller) {
                        if (msg.sender != auctions[auctionId].currentBidder) {

                            address previousBidder = auctions[auctionId].currentBidder;
                            uint256 previousBid = auctions[auctionId].currentBid;

                            if (previousBidder != address(0)) {
                                if (previousBid > 0) {
                                    if (auctionBids[auctionId][previousBidder] > 0) {

                                        pendingReturns[previousBidder] += previousBid;
                                        auctionBids[auctionId][previousBidder] = 0;
                                    }
                                }
                            }

                            auctions[auctionId].currentBid = msg.value;
                            auctions[auctionId].currentBidder = msg.sender;
                            auctionBids[auctionId][msg.sender] = msg.value;

                            emit BidPlaced(auctionId, msg.sender, msg.value);
                        } else {
                            revert("Cannot rebid");
                        }
                    } else {
                        revert("Seller cannot bid");
                    }
                } else {
                    revert("Bid too low");
                }
            } else {
                revert("Auction expired");
            }
        } else {
            revert("Auction ended");
        }
    }



    function getAuctionDetailsAndCalculateFeesAndValidateStatus(
        uint256 auctionId,
        bool includeDescription,
        bool calculateFees,
        address potentialBidder,
        uint256 potentialBidAmount,
        bool checkBidValidity
    ) public view returns (string memory, uint256, address, bool, uint256, bool) {
        Auction memory auction = auctions[auctionId];

        string memory details = includeDescription ? auction.description : auction.itemName;
        uint256 fees = calculateFees ? calculatePlatformFeeAndValidateAmount(auction.currentBid) : 0;
        bool isValidBid = false;

        if (checkBidValidity) {
            isValidBid = potentialBidAmount > auction.currentBid &&
                        potentialBidder != auction.seller &&
                        !auction.ended &&
                        block.timestamp < auction.endTime;
        }

        return (
            details,
            auction.currentBid,
            auction.currentBidder,
            auction.ended,
            fees,
            isValidBid
        );
    }

    function endAuction(uint256 auctionId) public {
        require(auctions[auctionId].exists, "Auction does not exist");
        require(!auctions[auctionId].ended, "Already ended");
        require(
            block.timestamp >= auctions[auctionId].endTime ||
            msg.sender == auctions[auctionId].seller ||
            msg.sender == owner,
            "Cannot end yet"
        );

        auctions[auctionId].ended = true;

        if (auctions[auctionId].currentBidder != address(0)) {
            uint256 finalBid = auctions[auctionId].currentBid;
            uint256 platformFee = calculatePlatformFeeAndValidateAmount(finalBid);
            uint256 sellerAmount = finalBid - platformFee;

            payable(auctions[auctionId].seller).transfer(sellerAmount);
            payable(owner).transfer(platformFee);

            emit AuctionEnded(auctionId, auctions[auctionId].currentBidder, finalBid);
        }
    }

    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }


    function validateAuctionExists(uint256 auctionId) public view returns (bool) {
        return auctions[auctionId].exists;
    }

    function getAuctionCount() public view returns (uint256) {
        return auctionCounter;
    }
}
