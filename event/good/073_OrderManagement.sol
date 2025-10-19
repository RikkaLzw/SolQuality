
pragma solidity ^0.8.0;

contract OrderManagement {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 orderId;
        address buyer;
        address seller;
        uint256 amount;
        string productName;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256[]) public sellerOrders;

    uint256 private nextOrderId = 1;
    address public owner;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        string productName
    );

    event OrderStatusUpdated(
        uint256 indexed orderId,
        OrderStatus indexed oldStatus,
        OrderStatus indexed newStatus,
        address updatedBy
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed cancelledBy,
        string reason
    );

    event PaymentReleased(
        uint256 indexed orderId,
        address indexed seller,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyBuyer(uint256 _orderId) {
        require(orders[_orderId].buyer == msg.sender, "Only the buyer can perform this action");
        _;
    }

    modifier onlySeller(uint256 _orderId) {
        require(orders[_orderId].seller == msg.sender, "Only the seller can perform this action");
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(orders[_orderId].orderId != 0, "Order does not exist");
        _;
    }

    modifier validStatus(uint256 _orderId, OrderStatus _requiredStatus) {
        require(orders[_orderId].status == _requiredStatus, "Invalid order status for this operation");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createOrder(
        address _seller,
        string memory _productName
    ) external payable returns (uint256) {
        require(_seller != address(0), "Seller address cannot be zero");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(msg.value > 0, "Order amount must be greater than zero");
        require(bytes(_productName).length > 0, "Product name cannot be empty");

        uint256 orderId = nextOrderId++;

        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            productName: _productName,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, msg.value, _productName);

        return orderId;
    }

    function confirmOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
        validStatus(_orderId, OrderStatus.Pending)
    {
        OrderStatus oldStatus = orders[_orderId].status;
        orders[_orderId].status = OrderStatus.Confirmed;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Confirmed, msg.sender);
    }

    function shipOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
        validStatus(_orderId, OrderStatus.Confirmed)
    {
        OrderStatus oldStatus = orders[_orderId].status;
        orders[_orderId].status = OrderStatus.Shipped;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Shipped, msg.sender);
    }

    function confirmDelivery(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyBuyer(_orderId)
        validStatus(_orderId, OrderStatus.Shipped)
    {
        OrderStatus oldStatus = orders[_orderId].status;
        orders[_orderId].status = OrderStatus.Delivered;
        orders[_orderId].updatedAt = block.timestamp;

        address seller = orders[_orderId].seller;
        uint256 amount = orders[_orderId].amount;

        (bool success, ) = seller.call{value: amount}("");
        if (!success) {
            revert("Payment transfer to seller failed");
        }

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Delivered, msg.sender);
        emit PaymentReleased(_orderId, seller, amount);
    }

    function cancelOrder(uint256 _orderId, string memory _reason)
        external
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];

        require(
            msg.sender == order.buyer || msg.sender == order.seller || msg.sender == owner,
            "Only buyer, seller, or owner can cancel the order"
        );

        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel order that is shipped or delivered"
        );

        require(bytes(_reason).length > 0, "Cancellation reason cannot be empty");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        address buyer = order.buyer;
        uint256 amount = order.amount;

        (bool success, ) = buyer.call{value: amount}("");
        if (!success) {
            revert("Refund transfer to buyer failed");
        }

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Cancelled, msg.sender);
        emit OrderCancelled(_orderId, msg.sender, _reason);
    }

    function getOrder(uint256 _orderId)
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
        returns (uint256[] memory)
    {
        require(_buyer != address(0), "Buyer address cannot be zero");
        return buyerOrders[_buyer];
    }

    function getSellerOrders(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        require(_seller != address(0), "Seller address cannot be zero");
        return sellerOrders[_seller];
    }

    function emergencyWithdraw(uint256 _orderId)
        external
        onlyOwner
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            order.status != OrderStatus.Delivered && order.status != OrderStatus.Cancelled,
            "Cannot withdraw from delivered or cancelled orders"
        );

        uint256 amount = order.amount;
        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;

        (bool success, ) = order.buyer.call{value: amount}("");
        if (!success) {
            revert("Emergency withdrawal failed");
        }

        emit OrderCancelled(_orderId, msg.sender, "Emergency withdrawal by owner");
    }

    receive() external payable {
        revert("Direct payments not accepted. Use createOrder function");
    }

    fallback() external payable {
        revert("Function not found. Check function signature");
    }
}
