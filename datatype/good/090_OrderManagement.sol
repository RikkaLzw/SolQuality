
pragma solidity ^0.8.0;

contract OrderManagement {

    enum OrderStatus {
        Pending,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled,
        Refunded
    }


    struct Order {
        bytes32 orderId;
        address buyer;
        address seller;
        uint256 amount;
        uint32 quantity;
        uint64 timestamp;
        OrderStatus status;
        bytes32 productHash;
        bool isPaid;
    }


    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public buyerOrders;
    mapping(address => bytes32[]) public sellerOrders;

    uint256 private orderCounter;
    address public owner;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint256 amount);
    event OrderStatusUpdated(bytes32 indexed orderId, OrderStatus newStatus);
    event PaymentReceived(bytes32 indexed orderId, uint256 amount);
    event OrderCancelled(bytes32 indexed orderId, address indexed cancelledBy);
    event RefundProcessed(bytes32 indexed orderId, uint256 amount);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyBuyer(bytes32 _orderId) {
        require(orders[_orderId].buyer == msg.sender, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(bytes32 _orderId) {
        require(orders[_orderId].seller == msg.sender, "Only seller can call this function");
        _;
    }

    modifier orderExists(bytes32 _orderId) {
        require(orders[_orderId].buyer != address(0), "Order does not exist");
        _;
    }

    modifier validStatus(bytes32 _orderId, OrderStatus _requiredStatus) {
        require(orders[_orderId].status == _requiredStatus, "Invalid order status");
        _;
    }

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
    }


    function createOrder(
        address _seller,
        uint32 _quantity,
        bytes32 _productHash
    ) external payable returns (bytes32) {
        require(_seller != address(0), "Invalid seller address");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(msg.value > 0, "Order amount must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");

        orderCounter++;
        bytes32 orderId = keccak256(abi.encodePacked(msg.sender, _seller, block.timestamp, orderCounter));

        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            quantity: _quantity,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            productHash: _productHash,
            isPaid: true
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, msg.value);
        emit PaymentReceived(orderId, msg.value);

        return orderId;
    }


    function confirmOrder(bytes32 _orderId)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
        validStatus(_orderId, OrderStatus.Pending)
    {
        orders[_orderId].status = OrderStatus.Confirmed;
        emit OrderStatusUpdated(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(bytes32 _orderId)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
        validStatus(_orderId, OrderStatus.Confirmed)
    {
        orders[_orderId].status = OrderStatus.Shipped;
        emit OrderStatusUpdated(_orderId, OrderStatus.Shipped);
    }


    function confirmDelivery(bytes32 _orderId)
        external
        orderExists(_orderId)
        onlyBuyer(_orderId)
        validStatus(_orderId, OrderStatus.Shipped)
    {
        orders[_orderId].status = OrderStatus.Delivered;


        address seller = orders[_orderId].seller;
        uint256 amount = orders[_orderId].amount;

        (bool success, ) = seller.call{value: amount}("");
        require(success, "Payment transfer failed");

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
            "Cannot cancel order in current status"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            (bool success, ) = order.buyer.call{value: order.amount}("");
            require(success, "Refund transfer failed");
            emit RefundProcessed(_orderId, order.amount);
        }

        emit OrderCancelled(_orderId, msg.sender);
        emit OrderStatusUpdated(_orderId, OrderStatus.Cancelled);
    }


    function requestRefund(bytes32 _orderId)
        external
        orderExists(_orderId)
        onlyBuyer(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Delivered,
            "Can only request refund for delivered orders"
        );

        order.status = OrderStatus.Refunded;


        if (order.isPaid) {
            (bool success, ) = order.buyer.call{value: order.amount}("");
            require(success, "Refund transfer failed");
            emit RefundProcessed(_orderId, order.amount);
        }

        emit OrderStatusUpdated(_orderId, OrderStatus.Refunded);
    }


    function getOrder(bytes32 _orderId)
        external
        view
        orderExists(_orderId)
        returns (
            bytes32 orderId,
            address buyer,
            address seller,
            uint256 amount,
            uint32 quantity,
            uint64 timestamp,
            OrderStatus status,
            bytes32 productHash,
            bool isPaid
        )
    {
        Order storage order = orders[_orderId];
        return (
            order.orderId,
            order.buyer,
            order.seller,
            order.amount,
            order.quantity,
            order.timestamp,
            order.status,
            order.productHash,
            order.isPaid
        );
    }


    function getBuyerOrders(address _buyer) external view returns (bytes32[] memory) {
        return buyerOrders[_buyer];
    }


    function getSellerOrders(address _seller) external view returns (bytes32[] memory) {
        return sellerOrders[_seller];
    }


    function getOrderStatus(bytes32 _orderId)
        external
        view
        orderExists(_orderId)
        returns (OrderStatus)
    {
        return orders[_orderId].status;
    }


    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
