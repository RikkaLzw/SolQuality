
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
        uint256 amount;
        uint32 quantity;
        uint64 timestamp;
        OrderStatus status;
        bool isPaid;
        bytes32 productHash;
    }


    mapping(bytes32 => Order) public orders;
    mapping(address => bytes32[]) public buyerOrders;
    mapping(address => bytes32[]) public sellerOrders;

    uint256 public totalOrders;
    address public owner;


    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed seller, uint256 amount);
    event OrderConfirmed(bytes32 indexed orderId);
    event OrderShipped(bytes32 indexed orderId);
    event OrderDelivered(bytes32 indexed orderId);
    event OrderCancelled(bytes32 indexed orderId);
    event PaymentReceived(bytes32 indexed orderId, uint256 amount);


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
        uint32 _quantity,
        bytes32 _productHash
    ) external payable {
        require(_seller != address(0), "Invalid seller address");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(msg.value > 0, "Order amount must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");
        require(orders[_orderId].buyer == address(0), "Order ID already exists");

        orders[_orderId] = Order({
            orderId: _orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            quantity: _quantity,
            timestamp: uint64(block.timestamp),
            status: OrderStatus.Pending,
            isPaid: true,
            productHash: _productHash
        });

        buyerOrders[msg.sender].push(_orderId);
        sellerOrders[_seller].push(_orderId);
        totalOrders++;

        emit OrderCreated(_orderId, msg.sender, _seller, msg.value);
        emit PaymentReceived(_orderId, msg.value);
    }


    function confirmOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Pending, "Order is not in pending status");

        orders[_orderId].status = OrderStatus.Confirmed;
        emit OrderConfirmed(_orderId);
    }


    function shipOrder(bytes32 _orderId)
        external
        onlySeller(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Confirmed, "Order is not confirmed");

        orders[_orderId].status = OrderStatus.Shipped;
        emit OrderShipped(_orderId);
    }


    function confirmDelivery(bytes32 _orderId)
        external
        onlyBuyer(_orderId)
        orderExists(_orderId)
    {
        require(orders[_orderId].status == OrderStatus.Shipped, "Order is not shipped");

        orders[_orderId].status = OrderStatus.Delivered;


        address payable seller = payable(orders[_orderId].seller);
        uint256 amount = orders[_orderId].amount;
        seller.transfer(amount);

        emit OrderDelivered(_orderId);
    }


    function cancelOrder(bytes32 _orderId)
        external
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Only buyer or seller can cancel order"
        );
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel order in current status"
        );

        order.status = OrderStatus.Cancelled;


        if (order.isPaid) {
            address payable buyer = payable(order.buyer);
            uint256 amount = order.amount;
            buyer.transfer(amount);
        }

        emit OrderCancelled(_orderId);
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
            order.quantity,
            order.timestamp,
            order.status,
            order.isPaid,
            order.productHash
        );
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
