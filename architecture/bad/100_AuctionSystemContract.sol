
pragma solidity ^0.8.0;

contract AuctionSystemContract {
    address public owner;
    uint256 public auctionCounter;

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
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(uint256 => address[]) public bidders;
    mapping(address => uint256[]) public userAuctions;
    mapping(address => uint256) public pendingReturns;

    event AuctionCreated(uint256 auctionId, address seller, string itemName, uint256 startingPrice, uint256 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 winningBid);
    event FundsWithdrawn(address user, uint256 amount);

    constructor() {
        owner = msg.sender;
        auctionCounter = 0;
    }

    function createAuction(string memory _itemName, string memory _description, uint256 _startingPrice, uint256 _duration) public {

        if (bytes(_itemName).length == 0) {
            revert("Item name cannot be empty");
        }
        if (_startingPrice == 0) {
            revert("Starting price must be greater than 0");
        }
        if (_duration < 3600) {
            revert("Duration must be at least 1 hour");
        }

        auctionCounter++;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            itemName: _itemName,
            description: _description,
            startingPrice: _startingPrice,
            currentBid: 0,
            currentBidder: address(0),
            endTime: endTime,
            ended: false,
            exists: true
        });

        userAuctions[msg.sender].push(auctionCounter);

        emit AuctionCreated(auctionCounter, msg.sender, _itemName, _startingPrice, endTime);
    }

    function placeBid(uint256 _auctionId) public payable {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        if (auctions[_auctionId].ended) {
            revert("Auction has ended");
        }
        if (block.timestamp >= auctions[_auctionId].endTime) {
            revert("Auction time has expired");
        }
        if (msg.sender == auctions[_auctionId].seller) {
            revert("Seller cannot bid on own auction");
        }

        uint256 minimumBid;
        if (auctions[_auctionId].currentBid == 0) {
            minimumBid = auctions[_auctionId].startingPrice;
        } else {
            minimumBid = auctions[_auctionId].currentBid + 1000000000000000;
        }

        if (msg.value < minimumBid) {
            revert("Bid amount too low");
        }


        if (auctions[_auctionId].currentBidder != address(0)) {
            pendingReturns[auctions[_auctionId].currentBidder] += auctions[_auctionId].currentBid;
        }

        auctions[_auctionId].currentBid = msg.value;
        auctions[_auctionId].currentBidder = msg.sender;


        if (bids[_auctionId][msg.sender] == 0) {
            bidders[_auctionId].push(msg.sender);
        }
        bids[_auctionId][msg.sender] = msg.value;

        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) public {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        if (auctions[_auctionId].ended) {
            revert("Auction already ended");
        }
        if (block.timestamp < auctions[_auctionId].endTime && msg.sender != auctions[_auctionId].seller && msg.sender != owner) {
            revert("Auction not yet ended");
        }

        auctions[_auctionId].ended = true;

        if (auctions[_auctionId].currentBidder != address(0)) {

            uint256 sellerAmount = auctions[_auctionId].currentBid;
            uint256 fee = sellerAmount * 25 / 1000;
            uint256 finalAmount = sellerAmount - fee;

            payable(auctions[_auctionId].seller).transfer(finalAmount);
            payable(owner).transfer(fee);

            emit AuctionEnded(_auctionId, auctions[_auctionId].currentBidder, auctions[_auctionId].currentBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    function withdrawFunds() public {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
            emit FundsWithdrawn(msg.sender, amount);
        }
    }


    function getAuctionInfo(uint256 _auctionId) public view returns (
        address seller,
        string memory itemName,
        string memory description,
        uint256 startingPrice,
        uint256 currentBid,
        address currentBidder,
        uint256 endTime,
        bool ended
    ) {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }

        Auction memory auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.description,
            auction.startingPrice,
            auction.currentBid,
            auction.currentBidder,
            auction.endTime,
            auction.ended
        );
    }

    function getUserAuctions(address _user) public view returns (uint256[] memory) {
        return userAuctions[_user];
    }

    function getAuctionBidders(uint256 _auctionId) public view returns (address[] memory) {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        return bidders[_auctionId];
    }

    function getUserBid(uint256 _auctionId, address _user) public view returns (uint256) {
        return bids[_auctionId][_user];
    }

    function getPendingReturns(address _user) public view returns (uint256) {
        return pendingReturns[_user];
    }

    function extendAuction(uint256 _auctionId, uint256 _additionalTime) public {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        if (auctions[_auctionId].ended) {
            revert("Auction has ended");
        }
        if (msg.sender != auctions[_auctionId].seller && msg.sender != owner) {
            revert("Only seller or owner can extend auction");
        }
        if (_additionalTime < 1800) {
            revert("Extension must be at least 30 minutes");
        }

        auctions[_auctionId].endTime += _additionalTime;
    }

    function cancelAuction(uint256 _auctionId) public {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        if (auctions[_auctionId].ended) {
            revert("Auction has ended");
        }
        if (msg.sender != auctions[_auctionId].seller && msg.sender != owner) {
            revert("Only seller or owner can cancel auction");
        }
        if (auctions[_auctionId].currentBidder != address(0)) {
            revert("Cannot cancel auction with active bids");
        }

        auctions[_auctionId].ended = true;
        emit AuctionEnded(_auctionId, address(0), 0);
    }

    function updateAuctionDescription(uint256 _auctionId, string memory _newDescription) public {

        if (!auctions[_auctionId].exists) {
            revert("Auction does not exist");
        }
        if (auctions[_auctionId].ended) {
            revert("Cannot update ended auction");
        }
        if (msg.sender != auctions[_auctionId].seller) {
            revert("Only seller can update description");
        }

        auctions[_auctionId].description = _newDescription;
    }

    function emergencyWithdraw() public {
        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }
        payable(owner).transfer(address(this).balance);
    }

    function changeOwner(address _newOwner) public {
        if (msg.sender != owner) {
            revert("Only current owner can change owner");
        }
        if (_newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }
        owner = _newOwner;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTotalAuctions() public view returns (uint256) {
        return auctionCounter;
    }


    function isAuctionActive(uint256 _auctionId) public view returns (bool) {
        if (!auctions[_auctionId].exists) {
            return false;
        }
        return !auctions[_auctionId].ended && block.timestamp < auctions[_auctionId].endTime;
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
