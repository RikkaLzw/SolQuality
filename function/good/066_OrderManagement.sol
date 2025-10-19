
pragma solidity ^0.8.0;

contract OrderManagement {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 id;
        address buyer;
        address seller;
        uint256 amount;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(uint256 => Order) private orders;
    mapping(address => uint256[]) private buyerOrders;
    mapping(address => uint256[]) private sellerOrders;

    uint256 private orderCounter;
    address private owner;

    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 amount);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus oldStatus, OrderStatus newStatus);
    event OrderCancelled(uint256 indexed orderId, address indexed cancelledBy);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 orderId) {
        require(
            msg.sender == orders[orderId].buyer || msg.sender == orders[orderId].seller,
            "Only buyer or seller can call this function"
        );
        _;
    }

    modifier orderExists(uint256 orderId) {
        require(orders[orderId].id != 0, "Order does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
    }

    function createOrder(address seller, uint256 amount) external payable returns (uint256) {
        require(seller != address(0), "Invalid seller address");
        require(amount > 0, "Amount must be greater than zero");
        require(msg.value == amount, "Sent value must equal order amount");

        orderCounter++;

        orders[orderCounter] = Order({
            id: orderCounter,
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        buyerOrders[msg.sender].push(orderCounter);
        sellerOrders[seller].push(orderCounter);

        emit OrderCreated(orderCounter, msg.sender, seller, amount);

        return orderCounter;
    }

    function confirmOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Only seller can confirm order");
        require(order.status == OrderStatus.Pending, "Order must be pending");

        _updateOrderStatus(orderId, OrderStatus.Confirmed);
    }

    function shipOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = orders[orderId];
        require(msg.sender == order.seller, "Only seller can ship order");
        require(order.status == OrderStatus.Confirmed, "Order must be confirmed");

        _updateOrderStatus(orderId, OrderStatus.Shipped);
    }

    function deliverOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = orders[orderId];
        require(msg.sender == order.buyer, "Only buyer can confirm delivery");
        require(order.status == OrderStatus.Shipped, "Order must be shipped");

        _updateOrderStatus(orderId, OrderStatus.Delivered);
        _releasePayment(orderId);
    }

    function cancelOrder(uint256 orderId) external orderExists(orderId) onlyBuyerOrSeller(orderId) {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel order in current status"
        );

        _updateOrderStatus(orderId, OrderStatus.Cancelled);
        _refundBuyer(orderId);

        emit OrderCancelled(orderId, msg.sender);
    }

    function getOrder(uint256 orderId) external view orderExists(orderId) returns (Order memory) {
        return orders[orderId];
    }

    function getBuyerOrders(address buyer) external view returns (uint256[] memory) {
        return buyerOrders[buyer];
    }

    function getSellerOrders(address seller) external view returns (uint256[] memory) {
        return sellerOrders[seller];
    }

    function getOrderStatus(uint256 orderId) external view orderExists(orderId) returns (OrderStatus) {
        return orders[orderId].status;
    }

    function _updateOrderStatus(uint256 orderId, OrderStatus newStatus) internal {
        OrderStatus oldStatus = orders[orderId].status;
        orders[orderId].status = newStatus;
        orders[orderId].updatedAt = block.timestamp;

        emit OrderStatusUpdated(orderId, oldStatus, newStatus);
    }

    function _releasePayment(uint256 orderId) internal {
        Order storage order = orders[orderId];
        payable(order.seller).transfer(order.amount);
    }

    function _refundBuyer(uint256 orderId) internal {
        Order storage order = orders[orderId];
        payable(order.buyer).transfer(order.amount);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function getContractBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }
}
