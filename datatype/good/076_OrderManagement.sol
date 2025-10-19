
pragma solidity ^0.8.0;

contract OrderManagement {

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
        uint32 quantity;
        OrderStatus status;
        bool isPaid;
        bytes32 productHash;
    }


    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public buyerOrders;
    mapping(address => bytes32[]) public sellerOrders;

    uint64 private orderCounter;
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
            amount: uint128(msg.value),
            timestamp: uint64(block.timestamp),
            quantity: _quantity,
            status: OrderStatus.Pending,
            isPaid: true,
            productHash: _productHash
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, uint128(msg.value));
        emit PaymentReceived(orderId, uint128(msg.value));

        return orderId;
    }


    function confirmOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Pending, "Order is not in pending status");

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


        address payable seller = payable(orders[_orderId].seller);
        uint128 amount = orders[_orderId].amount;

        seller.transfer(amount);

        emit OrderStatusUpdated(_orderId, OrderStatus.Delivered);
    }


    function cancelOrder(bytes32 _orderId)
        external
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Only buyer or seller can cancel the order"
        );
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel shipped or delivered order"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            address payable buyer = payable(order.buyer);
            uint128 amount = order.amount;
            buyer.transfer(amount);
        }

        emit OrderCancelled(_orderId);
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
            uint32 quantity,
            OrderStatus status,
            bool isPaid,
            bytes32 productHash
        )
    {
        Order storage order = orders[_orderId];
        return (
            order.orderId,
            order.buyer,
            order.seller,
            order.amount,
            order.timestamp,
            order.quantity,
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


    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
