
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

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;
    mapping(uint256 => mapping(address => uint256)) public auctionBids;

    uint256 public auctionCounter;
    address public owner;
    uint256 public platformFee = 25;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createAuctionAndManageSystem(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        bool shouldLogCreation,
        uint256 customFee,
        address alternativeSeller
    ) public {

        if (bytes(itemName).length > 0) {
            if (startingPrice > 0) {
                if (duration > 0) {

                    auctionCounter++;
                    address actualSeller = alternativeSeller != address(0) ? alternativeSeller : msg.sender;

                    auctions[auctionCounter] = Auction({
                        seller: actualSeller,
                        itemName: itemName,
                        description: description,
                        startingPrice: startingPrice,
                        currentBid: 0,
                        currentBidder: address(0),
                        endTime: block.timestamp + duration,
                        active: true,
                        ended: false
                    });


                    if (customFee > 0 && customFee <= 100) {
                        if (msg.sender == owner) {
                            platformFee = customFee;
                        }
                    }


                    if (shouldLogCreation) {
                        emit AuctionCreated(auctionCounter, actualSeller, itemName);
                    }
                } else {
                    revert("Invalid duration");
                }
            } else {
                revert("Invalid starting price");
            }
        } else {
            revert("Invalid item name");
        }
    }



    function placeBidAndProcessPayment(uint256 auctionId) public payable {
        if (auctionId > 0 && auctionId <= auctionCounter) {
            if (auctions[auctionId].active) {
                if (block.timestamp < auctions[auctionId].endTime) {
                    if (msg.value > auctions[auctionId].currentBid) {
                        if (msg.value >= auctions[auctionId].startingPrice) {
                            if (msg.sender != auctions[auctionId].seller) {

                                if (auctions[auctionId].currentBidder != address(0)) {
                                    if (auctions[auctionId].currentBid > 0) {
                                        pendingReturns[auctions[auctionId].currentBidder] += auctions[auctionId].currentBid;
                                    }
                                }


                                auctions[auctionId].currentBid = msg.value;
                                auctions[auctionId].currentBidder = msg.sender;
                                auctionBids[auctionId][msg.sender] = msg.value;

                                emit BidPlaced(auctionId, msg.sender, msg.value);
                            } else {
                                revert("Seller cannot bid");
                            }
                        } else {
                            revert("Bid below starting price");
                        }
                    } else {
                        revert("Bid too low");
                    }
                } else {
                    revert("Auction ended");
                }
            } else {
                revert("Auction not active");
            }
        } else {
            revert("Invalid auction ID");
        }
    }



    function endAuctionAndSettlePayments(uint256 auctionId) public returns (bool, uint256, address) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction");
        require(block.timestamp >= auctions[auctionId].endTime || msg.sender == auctions[auctionId].seller, "Cannot end yet");
        require(auctions[auctionId].active && !auctions[auctionId].ended, "Already ended");


        if (auctions[auctionId].currentBidder != address(0)) {
            if (auctions[auctionId].currentBid > 0) {

                uint256 fee = (auctions[auctionId].currentBid * platformFee) / 1000;
                uint256 sellerAmount = auctions[auctionId].currentBid - fee;


                if (sellerAmount > 0) {
                    (bool success, ) = auctions[auctionId].seller.call{value: sellerAmount}("");
                    require(success, "Transfer failed");
                }


                if (fee > 0) {
                    (bool feeSuccess, ) = owner.call{value: fee}("");
                    require(feeSuccess, "Fee transfer failed");
                }

                auctions[auctionId].active = false;
                auctions[auctionId].ended = true;

                emit AuctionEnded(auctionId, auctions[auctionId].currentBidder, auctions[auctionId].currentBid);

                return (true, auctions[auctionId].currentBid, auctions[auctionId].currentBidder);
            } else {
                auctions[auctionId].active = false;
                auctions[auctionId].ended = true;
                return (false, 0, address(0));
            }
        } else {
            auctions[auctionId].active = false;
            auctions[auctionId].ended = true;
            return (false, 0, address(0));
        }
    }


    function calculateFeeAndValidatePayment(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        return (amount * feeRate) / 1000;
    }



    function updateAuctionDetailsAndSystemSettings(
        uint256 auctionId,
        string memory newDescription,
        uint256 newEndTime,
        bool forceEnd,
        uint256 newPlatformFee,
        address newOwner
    ) public {
        if (msg.sender == owner || msg.sender == auctions[auctionId].seller) {
            if (auctionId > 0 && auctionId <= auctionCounter) {
                if (auctions[auctionId].active) {

                    if (bytes(newDescription).length > 0) {
                        auctions[auctionId].description = newDescription;
                    }


                    if (newEndTime > block.timestamp && newEndTime > auctions[auctionId].endTime) {
                        auctions[auctionId].endTime = newEndTime;
                    }


                    if (forceEnd && msg.sender == owner) {
                        auctions[auctionId].active = false;
                        auctions[auctionId].ended = true;
                    }


                    if (msg.sender == owner) {
                        if (newPlatformFee > 0 && newPlatformFee <= 100) {
                            platformFee = newPlatformFee;
                        }

                        if (newOwner != address(0)) {
                            owner = newOwner;
                        }
                    }
                }
            }
        }
    }

    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function getAuctionDetails(uint256 auctionId) public view returns (
        address seller,
        string memory itemName,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool active
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.active
        );
    }
}
