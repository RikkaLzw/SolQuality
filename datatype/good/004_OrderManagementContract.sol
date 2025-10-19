
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
    mapping(address => bytes32[]) public userOrders;

    uint32 public totalOrders;
    address public owner;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint128 amount);
    event OrderStatusUpdated(bytes32 indexed orderId, OrderStatus newStatus);
    event PaymentReceived(bytes32 indexed orderId, uint128 amount);
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
    ) external payable {
        require(_seller != address(0), "Invalid seller address");
        require(_amount > 0, "Amount must be greater than zero");
        require(orders[_orderId].buyer == address(0), "Order already exists");
        require(msg.value == _amount, "Payment amount mismatch");

        orders[_orderId] = Order({
            orderId: _orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            productHash: _productHash,
            isPaid: true
        });

        userOrders[msg.sender].push(_orderId);
        userOrders[_seller].push(_orderId);
        totalOrders++;

        emit OrderCreated(_orderId, msg.sender, _seller, _amount);
        emit PaymentReceived(_orderId, _amount);
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
            "Cannot cancel shipped or delivered order"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            (bool success, ) = payable(order.buyer).call{value: order.amount}("");
            require(success, "Refund transfer failed");
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


    function getUserOrders(address _user)
        external
        view
        returns (bytes32[] memory)
    {
        return userOrders[_user];
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
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
