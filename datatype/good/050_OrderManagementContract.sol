
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

    uint32 public totalOrders;
    address public owner;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint128 amount);
    event OrderStatusUpdated(bytes32 indexed orderId, OrderStatus newStatus);
    event OrderPaid(bytes32 indexed orderId, uint128 amount);
    event OrderCancelled(bytes32 indexed orderId);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyBuyer(bytes32 _orderId) {
        require(msg.sender == orders[_orderId].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(bytes32 _orderId) {
        require(msg.sender == orders[_orderId].seller, "Only seller can call this function");
        _;
    }

    modifier orderExists(bytes32 _orderId) {
        require(orders[_orderId].buyer != address(0), "Order does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function createOrder(
        bytes32 _orderId,
        address _seller,
        uint128 _amount,
        bytes32 _productHash
    ) external {
        require(_seller != address(0), "Invalid seller address");
        require(_amount > 0, "Amount must be greater than 0");
        require(orders[_orderId].buyer == address(0), "Order already exists");

        orders[_orderId] = Order({
            orderId: _orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            isPaid: false,
            productHash: _productHash
        });

        buyerOrders[msg.sender].push(_orderId);
        sellerOrders[_seller].push(_orderId);
        totalOrders++;

        emit OrderCreated(_orderId, msg.sender, _seller, _amount);
    }


    function payOrder(bytes32 _orderId)
        external
        payable
        onlyBuyer(_orderId)
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(!order.isPaid, "Order already paid");
        require(order.status == OrderStatus.Pending, "Invalid order status");
        require(msg.value == order.amount, "Incorrect payment amount");

        order.isPaid = true;
        order.status = OrderStatus.Confirmed;

        emit OrderPaid(_orderId, order.amount);
        emit OrderStatusUpdated(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.isPaid, "Order not paid");
        require(order.status == OrderStatus.Confirmed, "Invalid order status");

        order.status = OrderStatus.Shipped;

        emit OrderStatusUpdated(_orderId, OrderStatus.Shipped);
    }


    function confirmDelivery(bytes32 _orderId)
        external
        onlyBuyer(_orderId)
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.status == OrderStatus.Shipped, "Invalid order status");

        order.status = OrderStatus.Delivered;


        payable(order.seller).transfer(order.amount);

        emit OrderStatusUpdated(_orderId, OrderStatus.Delivered);
    }


    function cancelOrder(bytes32 _orderId)
        external
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Only buyer or seller can cancel"
        );
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel shipped or delivered order"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            payable(order.buyer).transfer(order.amount);
        }

        emit OrderCancelled(_orderId);
        emit OrderStatusUpdated(_orderId, OrderStatus.Cancelled);
    }


    function getOrder(bytes32 _orderId)
        external
        view
        orderExists(_orderId)
        returns (Order memory)
    {
        return orders[_orderId];
    }


    function getBuyerOrders(address _buyer)
        external
        view
        returns (bytes32[] memory)
    {
        return buyerOrders[_buyer];
    }


    function getSellerOrders(address _seller)
        external
        view
        returns (bytes32[] memory)
    {
        return sellerOrders[_seller];
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
