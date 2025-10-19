
pragma solidity ^0.8.0;

contract OrderManagementContract {

    enum OrderStatus {
        Pending,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled
    }


    struct Order {
        bytes32 orderId;
        address buyer;
        address seller;
        uint128 amount;
        uint64 timestamp;
        OrderStatus status;
        bool isPaid;
        bytes32 productHash;
    }


    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public buyerOrders;
    mapping(address => bytes32[]) public sellerOrders;

    address public owner;
    uint64 public totalOrders;
    bool public contractActive;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint128 amount);
    event OrderStatusUpdated(bytes32 indexed orderId, OrderStatus newStatus);
    event PaymentReceived(bytes32 indexed orderId, uint128 amount);
    event OrderCancelled(bytes32 indexed orderId, address indexed canceller);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveContract() {
        require(contractActive, "Contract is not active");
        _;
    }

    modifier validOrder(bytes32 _orderId) {
        require(orders[_orderId].buyer != address(0), "Order does not exist");
        _;
    }

    modifier onlyBuyerOrSeller(bytes32 _orderId) {
        require(
            msg.sender == orders[_orderId].buyer || msg.sender == orders[_orderId].seller,
            "Only buyer or seller can call this function"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
        totalOrders = 0;
    }


    function createOrder(
        bytes32 _orderId,
        address _seller,
        uint128 _amount,
        bytes32 _productHash
    ) external payable onlyActiveContract {
        require(_seller != address(0), "Invalid seller address");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(_amount > 0, "Amount must be greater than zero");
        require(orders[_orderId].buyer == address(0), "Order ID already exists");
        require(msg.value == _amount, "Payment amount mismatch");

        orders[_orderId] = Order({
            orderId: _orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            isPaid: true,
            productHash: _productHash
        });

        buyerOrders[msg.sender].push(_orderId);
        sellerOrders[_seller].push(_orderId);
        totalOrders++;

        emit OrderCreated(_orderId, msg.sender, _seller, _amount);
        emit PaymentReceived(_orderId, _amount);
    }


    function confirmOrder(bytes32 _orderId)
        external
        onlyActiveContract
        validOrder(_orderId)
    {
        Order storage order = orders[_orderId];
        require(msg.sender == order.seller, "Only seller can confirm order");
        require(order.status == OrderStatus.Pending, "Order is not in pending status");

        order.status = OrderStatus.Confirmed;
        emit OrderStatusUpdated(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(bytes32 _orderId)
        external
        onlyActiveContract
        validOrder(_orderId)
    {
        Order storage order = orders[_orderId];
        require(msg.sender == order.seller, "Only seller can ship order");
        require(order.status == OrderStatus.Confirmed, "Order must be confirmed first");

        order.status = OrderStatus.Shipped;
        emit OrderStatusUpdated(_orderId, OrderStatus.Shipped);
    }


    function deliverOrder(bytes32 _orderId)
        external
        onlyActiveContract
        validOrder(_orderId)
    {
        Order storage order = orders[_orderId];
        require(msg.sender == order.buyer, "Only buyer can confirm delivery");
        require(order.status == OrderStatus.Shipped, "Order must be shipped first");

        order.status = OrderStatus.Delivered;


        payable(order.seller).transfer(order.amount);

        emit OrderStatusUpdated(_orderId, OrderStatus.Delivered);
    }


    function cancelOrder(bytes32 _orderId)
        external
        onlyActiveContract
        validOrder(_orderId)
        onlyBuyerOrSeller(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel shipped or delivered order"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            payable(order.buyer).transfer(order.amount);
        }

        emit OrderCancelled(_orderId, msg.sender);
        emit OrderStatusUpdated(_orderId, OrderStatus.Cancelled);
    }


    function getOrder(bytes32 _orderId)
        external
        view
        validOrder(_orderId)
        returns (
            bytes32 orderId,
            address buyer,
            address seller,
            uint128 amount,
            uint64 timestamp,
            OrderStatus status,
            bool isPaid,
            bytes32 productHash
        )
    {
        Order memory order = orders[_orderId];
        return (
            order.orderId,
            order.buyer,
            order.seller,
            order.amount,
            order.timestamp,
            order.status,
            order.isPaid,
            order.productHash
        );
    }


    function getBuyerOrders(address _buyer) external view returns (bytes32[] memory) {
        return buyerOrders[_buyer];
    }


    function getSellerOrders(address _seller) external view returns (bytes32[] memory) {
        return sellerOrders[_seller];
    }


    function pauseContract() external onlyOwner {
        contractActive = false;
    }

    function resumeContract() external onlyOwner {
        contractActive = true;
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
