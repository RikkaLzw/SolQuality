
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
        bytes32 productHash;
        bool isPaid;
    }


    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public buyerOrders;
    mapping(address => bytes32[]) public sellerOrders;

    uint64 private orderCounter;
    address public owner;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint128 amount);
    event OrderStatusUpdated(bytes32 indexed orderId, OrderStatus newStatus);
    event OrderPaid(bytes32 indexed orderId, uint128 amount);
    event OrderCancelled(bytes32 indexed orderId, address indexed cancelledBy);


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

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
    }


    function createOrder(
        address _seller,
        uint128 _amount,
        bytes32 _productHash
    ) external payable returns (bytes32) {
        require(_seller != address(0), "Invalid seller address");
        require(_amount > 0, "Amount must be greater than zero");
        require(msg.value == _amount, "Payment amount mismatch");

        orderCounter++;
        bytes32 orderId = keccak256(abi.encodePacked(msg.sender, _seller, block.timestamp, orderCounter));

        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            productHash: _productHash,
            isPaid: true
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, _amount);
        emit OrderPaid(orderId, _amount);

        return orderId;
    }


    function confirmOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Pending, "Order cannot be confirmed");

        orders[_orderId].status = OrderStatus.Confirmed;
        emit OrderStatusUpdated(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Confirmed, "Order must be confirmed first");

        orders[_orderId].status = OrderStatus.Shipped;
        emit OrderStatusUpdated(_orderId, OrderStatus.Shipped);
    }


    function confirmDelivery(bytes32 _orderId)
        external
        onlyBuyer(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Shipped, "Order must be shipped first");

        orders[_orderId].status = OrderStatus.Delivered;


        address seller = orders[_orderId].seller;
        uint128 amount = orders[_orderId].amount;

        (bool success, ) = payable(seller).call{value: amount}("");
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
            "Order cannot be cancelled at this stage"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            (bool success, ) = payable(order.buyer).call{value: order.amount}("");
            require(success, "Refund transfer failed");
        }

        emit OrderCancelled(_orderId, msg.sender);
        emit OrderStatusUpdated(_orderId, OrderStatus.Cancelled);
    }


    function getOrder(bytes32 _orderId)
        external
        view
        orderExists(_orderId)
        returns (
            bytes32 orderId,
            address buyer,
            address seller,
            uint128 amount,
            uint64 timestamp,
            OrderStatus status,
            bytes32 productHash,
            bool isPaid
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


    function getOrderCount() external view returns (uint64) {
        return orderCounter;
    }


    function emergencyWithdraw() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }
}
