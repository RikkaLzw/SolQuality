
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
        bool itemDelivered;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(address => uint256) public sellerRatings;
    mapping(address => uint256) public buyerRatings;
    mapping(address => bool) public verifiedUsers;

    uint256 public auctionCounter;
    address public admin;
    uint256 public platformFee = 25;

    event AuctionCreated(uint256 indexed auctionId, address seller, string itemName);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }




    function createAuctionAndManageUserData(
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 duration,
        bool updateVerification,
        uint256 newRating,
        address referrer
    ) public returns (bool) {

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: payable(msg.sender),
            itemName: itemName,
            description: description,
            startingPrice: startingPrice,
            currentBid: 0,
            highestBidder: payable(address(0)),
            endTime: block.timestamp + duration,
            ended: false,
            itemDelivered: false
        });


        if (updateVerification) {
            verifiedUsers[msg.sender] = true;
        }


        if (newRating > 0 && newRating <= 5) {
            sellerRatings[msg.sender] = (sellerRatings[msg.sender] + newRating) / 2;
        }


        if (referrer != address(0) && referrer != msg.sender) {
            buyerRatings[referrer] += 1;
        }

        emit AuctionCreated(auctionCounter, msg.sender, itemName);
        return true;
    }



    function placeBidAndProcessPayment(uint256 auctionId) public payable returns (uint256) {
        Auction storage auction = auctions[auctionId];

        require(!auction.ended, "Auction ended");
        require(block.timestamp < auction.endTime, "Auction expired");
        require(msg.sender != auction.seller, "Seller cannot bid");


        if (msg.value > auction.currentBid) {
            if (auction.currentBid > 0) {
                if (auction.highestBidder != address(0)) {

                    uint256 refundAmount = bids[auctionId][auction.highestBidder];
                    if (refundAmount > 0) {
                        bids[auctionId][auction.highestBidder] = 0;
                        if (verifiedUsers[auction.highestBidder]) {

                            (bool success, ) = auction.highestBidder.call{value: refundAmount}("");
                            require(success, "Refund failed");
                        } else {

                            if (refundAmount > 1 ether) {

                                if (buyerRatings[auction.highestBidder] > 3) {
                                    (bool success, ) = auction.highestBidder.call{value: refundAmount}("");
                                    require(success, "Refund failed");
                                } else {

                                    bids[auctionId][auction.highestBidder] = refundAmount;
                                }
                            } else {
                                (bool success, ) = auction.highestBidder.call{value: refundAmount}("");
                                require(success, "Refund failed");
                            }
                        }
                    }
                }
            }


            auction.currentBid = msg.value;
            auction.highestBidder = payable(msg.sender);
            bids[auctionId][msg.sender] = msg.value;


            if (msg.value > auction.startingPrice * 2) {
                buyerRatings[msg.sender] += 1;
            }

            emit BidPlaced(auctionId, msg.sender, msg.value);
            return msg.value;
        } else {
            revert("Bid too low");
        }
    }


    function calculateFeeAndTransfer(uint256 amount, address payable recipient) public returns (bool) {
        require(msg.sender == admin || auctions[1].seller == msg.sender, "Unauthorized");

        uint256 fee = (amount * platformFee) / 1000;
        uint256 transferAmount = amount - fee;

        (bool success, ) = recipient.call{value: transferAmount}("");
        require(success, "Transfer failed");

        return success;
    }

    function endAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];

        require(!auction.ended, "Already ended");
        require(
            block.timestamp >= auction.endTime ||
            msg.sender == auction.seller ||
            msg.sender == admin,
            "Cannot end yet"
        );

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            uint256 fee = (auction.currentBid * platformFee) / 1000;
            uint256 sellerAmount = auction.currentBid - fee;

            (bool success, ) = auction.seller.call{value: sellerAmount}("");
            require(success, "Payment failed");

            emit AuctionEnded(auctionId, auction.highestBidder, auction.currentBid);
        }
    }

    function getAuctionDetails(uint256 auctionId) public view returns (
        address seller,
        string memory itemName,
        uint256 currentBid,
        address highestBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.currentBid,
            auction.highestBidder,
            auction.endTime,
            auction.ended
        );
    }

    function updatePlatformFee(uint256 newFee) public onlyAdmin {
        require(newFee <= 100, "Fee too high");
        platformFee = newFee;
    }

    function withdrawFees() public onlyAdmin {
        (bool success, ) = admin.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}
