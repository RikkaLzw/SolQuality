
pragma solidity ^0.8.0;

contract OrderManagement {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 id;
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

    uint256 public nextOrderId;
    uint256 public totalOrders;

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

    event PaymentProcessed(
        uint256 indexed orderId,
        address indexed buyer,
        uint256 amount
    );

    modifier onlyOrderParticipant(uint256 _orderId) {
        require(
            orders[_orderId].buyer == msg.sender || orders[_orderId].seller == msg.sender,
            "OrderManagement: Only buyer or seller can perform this action"
        );
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(_orderId < nextOrderId, "OrderManagement: Order does not exist");
        require(orders[_orderId].buyer != address(0), "OrderManagement: Order has been deleted");
        _;
    }

    modifier validStatus(OrderStatus _status) {
        require(
            _status >= OrderStatus.Pending && _status <= OrderStatus.Cancelled,
            "OrderManagement: Invalid order status"
        );
        _;
    }

    constructor() {
        nextOrderId = 1;
        totalOrders = 0;
    }

    function createOrder(
        address _seller,
        string memory _productName
    ) external payable returns (uint256) {
        require(_seller != address(0), "OrderManagement: Invalid seller address");
        require(_seller != msg.sender, "OrderManagement: Buyer and seller cannot be the same");
        require(msg.value > 0, "OrderManagement: Order amount must be greater than zero");
        require(bytes(_productName).length > 0, "OrderManagement: Product name cannot be empty");

        uint256 orderId = nextOrderId;

        orders[orderId] = Order({
            id: orderId,
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

        nextOrderId++;
        totalOrders++;

        emit OrderCreated(orderId, msg.sender, _seller, msg.value, _productName);
        emit PaymentProcessed(orderId, msg.sender, msg.value);

        return orderId;
    }

    function confirmOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyOrderParticipant(_orderId)
    {
        Order storage order = orders[_orderId];

        require(order.status == OrderStatus.Pending, "OrderManagement: Order is not in pending status");
        require(msg.sender == order.seller, "OrderManagement: Only seller can confirm the order");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Confirmed;
        order.updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Confirmed, msg.sender);
    }

    function shipOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyOrderParticipant(_orderId)
    {
        Order storage order = orders[_orderId];

        require(order.status == OrderStatus.Confirmed, "OrderManagement: Order must be confirmed before shipping");
        require(msg.sender == order.seller, "OrderManagement: Only seller can ship the order");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Shipped;
        order.updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Shipped, msg.sender);
    }

    function deliverOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyOrderParticipant(_orderId)
    {
        Order storage order = orders[_orderId];

        require(order.status == OrderStatus.Shipped, "OrderManagement: Order must be shipped before delivery");
        require(msg.sender == order.buyer, "OrderManagement: Only buyer can confirm delivery");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Delivered;
        order.updatedAt = block.timestamp;


        (bool success, ) = payable(order.seller).call{value: order.amount}("");
        if (!success) {
            revert("OrderManagement: Failed to transfer payment to seller");
        }

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Delivered, msg.sender);
    }

    function cancelOrder(uint256 _orderId, string memory _reason)
        external
        orderExists(_orderId)
        onlyOrderParticipant(_orderId)
    {
        Order storage order = orders[_orderId];

        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "OrderManagement: Cannot cancel order that has been shipped or delivered"
        );
        require(bytes(_reason).length > 0, "OrderManagement: Cancellation reason cannot be empty");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        (bool success, ) = payable(order.buyer).call{value: order.amount}("");
        if (!success) {
            revert("OrderManagement: Failed to refund buyer");
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
        require(_buyer != address(0), "OrderManagement: Invalid buyer address");
        return buyerOrders[_buyer];
    }

    function getSellerOrders(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        require(_seller != address(0), "OrderManagement: Invalid seller address");
        return sellerOrders[_seller];
    }

    function getOrdersByStatus(OrderStatus _status)
        external
        view
        validStatus(_status)
        returns (uint256[] memory)
    {
        uint256[] memory result = new uint256[](totalOrders);
        uint256 count = 0;

        for (uint256 i = 1; i < nextOrderId; i++) {
            if (orders[i].buyer != address(0) && orders[i].status == _status) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory filteredResult = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            filteredResult[j] = result[j];
        }

        return filteredResult;
    }

    function getTotalOrdersByStatus(OrderStatus _status)
        external
        view
        validStatus(_status)
        returns (uint256)
    {
        uint256 count = 0;

        for (uint256 i = 1; i < nextOrderId; i++) {
            if (orders[i].buyer != address(0) && orders[i].status == _status) {
                count++;
            }
        }

        return count;
    }
}
