
pragma solidity ^0.8.0;

contract OrderManagementContract {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 orderId;
        address buyer;
        address seller;
        uint256 amount;
        uint256 timestamp;
        OrderStatus status;
        bytes32 productHash;
    }


    uint256 private _orderCounter;
    mapping(uint256 => Order) private _orders;
    mapping(address => uint256[]) private _buyerOrders;
    mapping(address => uint256[]) private _sellerOrders;
    mapping(address => mapping(OrderStatus => uint256)) private _statusCounts;


    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 amount);
    event OrderStatusChanged(uint256 indexed orderId, OrderStatus oldStatus, OrderStatus newStatus);
    event OrderCancelled(uint256 indexed orderId, address indexed canceller);


    modifier orderExists(uint256 orderId) {
        require(_orders[orderId].buyer != address(0), "Order does not exist");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 orderId) {
        Order storage order = _orders[orderId];
        require(msg.sender == order.buyer || msg.sender == order.seller, "Not authorized");
        _;
    }

    modifier validStatus(OrderStatus status) {
        require(uint8(status) <= uint8(OrderStatus.Cancelled), "Invalid status");
        _;
    }

    function createOrder(
        address seller,
        bytes32 productHash
    ) external payable returns (uint256) {
        require(seller != address(0), "Invalid seller address");
        require(seller != msg.sender, "Cannot create order with yourself");
        require(msg.value > 0, "Order amount must be greater than 0");


        uint256 orderId = ++_orderCounter;


        Order memory newOrder = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: seller,
            amount: msg.value,
            timestamp: block.timestamp,
            status: OrderStatus.Pending,
            productHash: productHash
        });

        _orders[orderId] = newOrder;


        _buyerOrders[msg.sender].push(orderId);
        _sellerOrders[seller].push(orderId);


        unchecked {
            _statusCounts[msg.sender][OrderStatus.Pending]++;
            _statusCounts[seller][OrderStatus.Pending]++;
        }

        emit OrderCreated(orderId, msg.sender, seller, msg.value);
        return orderId;
    }

    function confirmOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = _orders[orderId];
        require(msg.sender == order.seller, "Only seller can confirm");
        require(order.status == OrderStatus.Pending, "Invalid status transition");

        _updateOrderStatus(orderId, OrderStatus.Confirmed);
    }

    function shipOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = _orders[orderId];
        require(msg.sender == order.seller, "Only seller can ship");
        require(order.status == OrderStatus.Confirmed, "Order must be confirmed first");

        _updateOrderStatus(orderId, OrderStatus.Shipped);
    }

    function deliverOrder(uint256 orderId) external orderExists(orderId) {
        Order storage order = _orders[orderId];
        require(msg.sender == order.buyer, "Only buyer can confirm delivery");
        require(order.status == OrderStatus.Shipped, "Order must be shipped first");

        _updateOrderStatus(orderId, OrderStatus.Delivered);


        address seller = order.seller;
        uint256 amount = order.amount;

        (bool success, ) = seller.call{value: amount}("");
        require(success, "Payment transfer failed");
    }

    function cancelOrder(uint256 orderId) external orderExists(orderId) onlyBuyerOrSeller(orderId) {
        Order storage order = _orders[orderId];
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
                "Cannot cancel shipped or delivered order");

        OrderStatus oldStatus = order.status;
        _updateOrderStatus(orderId, OrderStatus.Cancelled);


        if (order.amount > 0) {
            address buyer = order.buyer;
            uint256 amount = order.amount;

            (bool success, ) = buyer.call{value: amount}("");
            require(success, "Refund failed");
        }

        emit OrderCancelled(orderId, msg.sender);
    }

    function _updateOrderStatus(uint256 orderId, OrderStatus newStatus) private {
        Order storage order = _orders[orderId];
        OrderStatus oldStatus = order.status;

        if (oldStatus != newStatus) {
            order.status = newStatus;


            address buyer = order.buyer;
            address seller = order.seller;

            unchecked {
                _statusCounts[buyer][oldStatus]--;
                _statusCounts[buyer][newStatus]++;
                _statusCounts[seller][oldStatus]--;
                _statusCounts[seller][newStatus]++;
            }

            emit OrderStatusChanged(orderId, oldStatus, newStatus);
        }
    }

    function getOrder(uint256 orderId) external view orderExists(orderId) returns (
        address buyer,
        address seller,
        uint256 amount,
        uint256 timestamp,
        OrderStatus status,
        bytes32 productHash
    ) {
        Order storage order = _orders[orderId];
        return (
            order.buyer,
            order.seller,
            order.amount,
            order.timestamp,
            order.status,
            order.productHash
        );
    }

    function getBuyerOrders(address buyer) external view returns (uint256[] memory) {
        return _buyerOrders[buyer];
    }

    function getSellerOrders(address seller) external view returns (uint256[] memory) {
        return _sellerOrders[seller];
    }

    function getOrdersByStatus(address user, OrderStatus status) external view validStatus(status) returns (uint256[] memory) {
        uint256[] memory userOrders = _buyerOrders[user];
        uint256 count = _statusCounts[user][status];
        uint256[] memory result = new uint256[](count);

        uint256 index = 0;
        uint256 length = userOrders.length;

        for (uint256 i = 0; i < length && index < count; ) {
            uint256 orderId = userOrders[i];
            if (_orders[orderId].status == status) {
                result[index] = orderId;
                unchecked { ++index; }
            }
            unchecked { ++i; }
        }

        return result;
    }

    function getStatusCount(address user, OrderStatus status) external view validStatus(status) returns (uint256) {
        return _statusCounts[user][status];
    }

    function getTotalOrders() external view returns (uint256) {
        return _orderCounter;
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external {
        revert("Function not found");
    }
}
