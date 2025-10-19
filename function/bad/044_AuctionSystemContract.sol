
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool isActive;
    }

    struct Auction {
        address seller;
        string itemName;
        string description;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address currentHighestBidder;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isFinalized;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bidderBalances;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public userAuctions;

    uint256 public auctionCounter;
    uint256 public platformFeeRate = 25;
    address public platformOwner;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionFinalized(uint256 indexed auctionId, address indexed winner, uint256 amount);

    constructor() {
        platformOwner = msg.sender;
    }




    function createAuctionAndManagePlatform(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        bool shouldUpdateFeeRate,
        uint256 newFeeRate,
        bool shouldTransferOwnership,
        address newOwner
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
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            isFinalized: false
        });

        userAuctions[msg.sender].push(auctionCounter);
        emit AuctionCreated(auctionCounter, msg.sender, itemName);


        if (shouldUpdateFeeRate && msg.sender == platformOwner) {
            require(newFeeRate <= 100, "Fee rate too high");
            platformFeeRate = newFeeRate;
        }


        if (shouldTransferOwnership && msg.sender == platformOwner) {
            require(newOwner != address(0), "Invalid new owner");
            platformOwner = newOwner;
        }
    }



    function placeBidWithComplexValidation(uint256 auctionId) public payable {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");

        Auction storage auction = auctions[auctionId];

        if (auction.isActive) {
            if (block.timestamp >= auction.startTime) {
                if (block.timestamp <= auction.endTime) {
                    if (msg.sender != auction.seller) {
                        if (msg.value > auction.currentHighestBid) {
                            if (msg.value >= auction.startingPrice) {
                                if (auction.currentHighestBidder != address(0)) {
                                    if (bidderBalances[auctionId][auction.currentHighestBidder] > 0) {
                                        uint256 refundAmount = bidderBalances[auctionId][auction.currentHighestBidder];
                                        bidderBalances[auctionId][auction.currentHighestBidder] = 0;
                                        payable(auction.currentHighestBidder).transfer(refundAmount);
                                    }
                                }

                                auction.currentHighestBid = msg.value;
                                auction.currentHighestBidder = msg.sender;
                                bidderBalances[auctionId][msg.sender] = msg.value;

                                auctionBids[auctionId].push(Bid({
                                    bidder: msg.sender,
                                    amount: msg.value,
                                    timestamp: block.timestamp,
                                    isActive: true
                                }));

                                emit BidPlaced(auctionId, msg.sender, msg.value);
                            } else {
                                revert("Bid below starting price");
                            }
                        } else {
                            revert("Bid not higher than current highest");
                        }
                    } else {
                        revert("Seller cannot bid on own auction");
                    }
                } else {
                    revert("Auction has ended");
                }
            } else {
                revert("Auction has not started");
            }
        } else {
            revert("Auction is not active");
        }
    }


    function getAuctionDetailsAndPlatformInfo(uint256 auctionId) public view returns (
        address, string memory, uint256, uint256, address, bool, uint256, address, uint256
    ) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");

        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.startingPrice,
            auction.currentHighestBid,
            auction.currentHighestBidder,
            auction.isActive,
            platformFeeRate,
            platformOwner,
            block.timestamp
        );
    }

    function finalizeAuction(uint256 auctionId) public {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");

        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp > auction.endTime, "Auction still ongoing");
        require(!auction.isFinalized, "Auction already finalized");
        require(msg.sender == auction.seller || msg.sender == platformOwner, "Not authorized");

        auction.isActive = false;
        auction.isFinalized = true;

        if (auction.currentHighestBidder != address(0)) {
            uint256 platformFee = (auction.currentHighestBid * platformFeeRate) / 1000;
            uint256 sellerAmount = auction.currentHighestBid - platformFee;

            bidderBalances[auctionId][auction.currentHighestBidder] = 0;

            payable(auction.seller).transfer(sellerAmount);
            payable(platformOwner).transfer(platformFee);

            emit AuctionFinalized(auctionId, auction.currentHighestBidder, auction.currentHighestBid);
        }
    }

    function getUserAuctions(address user) public view returns (uint256[] memory) {
        return userAuctions[user];
    }

    function getAuctionBidsCount(uint256 auctionId) public view returns (uint256) {
        return auctionBids[auctionId].length;
    }

    function getAuctionBid(uint256 auctionId, uint256 bidIndex) public view returns (
        address bidder,
        uint256 amount,
        uint256 timestamp,
        bool isActive
    ) {
        require(bidIndex < auctionBids[auctionId].length, "Invalid bid index");

        Bid storage bid = auctionBids[auctionId][bidIndex];
        return (bid.bidder, bid.amount, bid.timestamp, bid.isActive);
    }
}
