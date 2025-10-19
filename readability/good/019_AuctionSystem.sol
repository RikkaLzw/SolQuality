
pragma solidity ^0.8.0;


contract AuctionSystem {

    enum AuctionState {
        Active,
        Ended,
        Cancelled
    }


    struct Auction {
        address payable seller;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 currentHighestBid;
        address payable currentHighestBidder;
        uint256 auctionEndTime;
        AuctionState state;
        bool sellerWithdrawn;
    }


    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    uint256 public nextAuctionId;
    uint256 public constant MINIMUM_BID_INCREMENT = 0.01 ether;
    uint256 public constant MINIMUM_AUCTION_DURATION = 1 hours;


    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        uint256 startingPrice,
        uint256 endTime
    );

    event NewBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(
        uint256 indexed auctionId,
        address indexed seller
    );

    event FundsWithdrawn(
        uint256 indexed auctionId,
        address indexed recipient,
        uint256 amount
    );


    modifier onlyActiveBid(uint256 _auctionId) {
        require(auctions[_auctionId].state == AuctionState.Active, "拍卖未激活");
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "拍卖已结束");
        _;
    }

    modifier onlyAuctionSeller(uint256 _auctionId) {
        require(msg.sender == auctions[_auctionId].seller, "只有卖家可以执行此操作");
        _;
    }

    modifier auctionExists(uint256 _auctionId) {
        require(_auctionId < nextAuctionId, "拍卖不存在");
        _;
    }


    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _duration
    ) external returns (uint256 auctionId) {
        require(bytes(_itemName).length > 0, "物品名称不能为空");
        require(_startingPrice > 0, "起拍价必须大于0");
        require(_duration >= MINIMUM_AUCTION_DURATION, "拍卖时长不能少于1小时");

        auctionId = nextAuctionId++;
        uint256 endTime = block.timestamp + _duration;

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            currentHighestBid: 0,
            currentHighestBidder: payable(address(0)),
            auctionEndTime: endTime,
            state: AuctionState.Active,
            sellerWithdrawn: false
        });

        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, endTime);
    }


    function placeBid(uint256 _auctionId)
        external
        payable
        auctionExists(_auctionId)
        onlyActiveBid(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(msg.sender != auction.seller, "卖家不能对自己的拍卖出价");
        require(msg.value > 0, "出价必须大于0");

        uint256 minimumBid = auction.currentHighestBid == 0
            ? auction.startingPrice
            : auction.currentHighestBid + MINIMUM_BID_INCREMENT;

        require(msg.value >= minimumBid, "出价过低");


        if (auction.currentHighestBidder != address(0)) {
            pendingReturns[_auctionId][auction.currentHighestBidder] += auction.currentHighestBid;
        }


        auction.currentHighestBid = msg.value;
        auction.currentHighestBidder = payable(msg.sender);

        emit NewBid(_auctionId, msg.sender, msg.value);
    }


    function endAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(auction.state == AuctionState.Active, "拍卖未激活");
        require(
            block.timestamp >= auction.auctionEndTime || msg.sender == auction.seller,
            "拍卖尚未到期且您不是卖家"
        );

        auction.state = AuctionState.Ended;

        emit AuctionEnded(
            _auctionId,
            auction.currentHighestBidder,
            auction.currentHighestBid
        );
    }


    function cancelAuction(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlyAuctionSeller(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(auction.state == AuctionState.Active, "拍卖未激活");
        require(auction.currentHighestBidder == address(0), "已有出价，无法取消");

        auction.state = AuctionState.Cancelled;

        emit AuctionCancelled(_auctionId, msg.sender);
    }


    function withdrawSellerFunds(uint256 _auctionId)
        external
        auctionExists(_auctionId)
        onlyAuctionSeller(_auctionId)
    {
        Auction storage auction = auctions[_auctionId];

        require(auction.state == AuctionState.Ended, "拍卖尚未结束");
        require(!auction.sellerWithdrawn, "资金已提取");
        require(auction.currentHighestBid > 0, "无收益可提取");

        auction.sellerWithdrawn = true;
        uint256 amount = auction.currentHighestBid;

        (bool success, ) = auction.seller.call{value: amount}("");
        require(success, "转账失败");

        emit FundsWithdrawn(_auctionId, auction.seller, amount);
    }


    function withdrawBid(uint256 _auctionId)
        external
        auctionExists(_auctionId)
    {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "无资金可提取");

        pendingReturns[_auctionId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "转账失败");

        emit FundsWithdrawn(_auctionId, msg.sender, amount);
    }


    function getAuctionDetails(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (Auction memory auction)
    {
        return auctions[_auctionId];
    }


    function getPendingReturn(uint256 _auctionId, address _bidder)
        external
        view
        auctionExists(_auctionId)
        returns (uint256 amount)
    {
        return pendingReturns[_auctionId][_bidder];
    }


    function isAuctionEnded(uint256 _auctionId)
        external
        view
        auctionExists(_auctionId)
        returns (bool isEnded)
    {
        Auction storage auction = auctions[_auctionId];
        return auction.state == AuctionState.Ended ||
               block.timestamp >= auction.auctionEndTime;
    }


    function getActiveAuctionCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < nextAuctionId; i++) {
            if (auctions[i].state == AuctionState.Active &&
                block.timestamp < auctions[i].auctionEndTime) {
                count++;
            }
        }
    }
}
