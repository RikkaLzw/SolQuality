
pragma solidity ^0.8.0;

contract OrderManagement {

    address private owner;
    uint256 private nextOrderId;
    uint256 private totalOrders;


    enum OrderStatus {
        Pending,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled
    }


    struct Order {
        address customer;
        uint128 amount;
        uint64 timestamp;
        uint32 productId;
        OrderStatus status;
    }


    mapping(uint256 => Order) private orders;
    mapping(address => uint256[]) private customerOrders;
    mapping(uint32 => uint256) private productOrderCount;


    event OrderCreated(uint256 indexed orderId, address indexed customer, uint32 indexed productId, uint128 amount);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus indexed newStatus);
    event OrderCancelled(uint256 indexed orderId, address indexed customer);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validOrderId(uint256 orderId) {
        require(orderId > 0 && orderId < nextOrderId, "Invalid order ID");
        _;
    }

    modifier onlyCustomer(uint256 orderId) {
        require(orders[orderId].customer == msg.sender, "Not order customer");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextOrderId = 1;
    }


    function createOrder(uint32 productId, uint128 amount) external payable returns (uint256) {
        require(amount > 0, "Amount must be positive");
        require(msg.value >= amount, "Insufficient payment");

        uint256 orderId = nextOrderId;


        Order storage newOrder = orders[orderId];
        newOrder.customer = msg.sender;
        newOrder.amount = amount;
        newOrder.timestamp = uint64(block.timestamp);
        newOrder.productId = productId;
        newOrder.status = OrderStatus.Pending;


        customerOrders[msg.sender].push(orderId);
        unchecked {
            ++productOrderCount[productId];
            ++nextOrderId;
            ++totalOrders;
        }


        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }

        emit OrderCreated(orderId, msg.sender, productId, amount);
        return orderId;
    }


    function createBatchOrders(uint32[] calldata productIds, uint128[] calldata amounts)
        external
        payable
        returns (uint256[] memory orderIds)
    {
        require(productIds.length == amounts.length, "Array length mismatch");
        require(productIds.length > 0, "Empty arrays");

        uint256 length = productIds.length;
        orderIds = new uint256[](length);

        uint256 totalRequired = 0;

        for (uint256 i = 0; i < length;) {
            require(amounts[i] > 0, "Amount must be positive");
            totalRequired += amounts[i];
            unchecked { ++i; }
        }

        require(msg.value >= totalRequired, "Insufficient payment");


        uint256 currentOrderId = nextOrderId;
        address customer = msg.sender;
        uint64 timestamp = uint64(block.timestamp);

        for (uint256 i = 0; i < length;) {
            uint256 orderId = currentOrderId + i;
            orderIds[i] = orderId;

            Order storage newOrder = orders[orderId];
            newOrder.customer = customer;
            newOrder.amount = amounts[i];
            newOrder.timestamp = timestamp;
            newOrder.productId = productIds[i];
            newOrder.status = OrderStatus.Pending;

            customerOrders[customer].push(orderId);
            unchecked {
                ++productOrderCount[productIds[i]];
                ++i;
            }

            emit OrderCreated(orderId, customer, productIds[i], amounts[i]);
        }

        unchecked {
            nextOrderId += length;
            totalOrders += length;
        }


        if (msg.value > totalRequired) {
            payable(customer).transfer(msg.value - totalRequired);
        }
    }


    function updateOrderStatus(uint256 orderId, OrderStatus newStatus)
        external
        onlyOwner
        validOrderId(orderId)
    {
        Order storage order = orders[orderId];
        require(order.status != OrderStatus.Cancelled, "Cannot update cancelled order");
        require(order.status != OrderStatus.Delivered, "Order already delivered");
        require(newStatus != OrderStatus.Pending || order.status == OrderStatus.Pending, "Invalid status transition");

        order.status = newStatus;
        emit OrderStatusUpdated(orderId, newStatus);
    }


    function cancelOrder(uint256 orderId)
        external
        validOrderId(orderId)
        onlyCustomer(orderId)
    {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed, "Cannot cancel order");

        order.status = OrderStatus.Cancelled;


        uint128 refundAmount = order.amount;
        payable(order.customer).transfer(refundAmount);

        emit OrderCancelled(orderId, order.customer);
    }


    function getOrder(uint256 orderId)
        external
        view
        validOrderId(orderId)
        returns (address customer, uint128 amount, uint64 timestamp, uint32 productId, OrderStatus status)
    {
        Order memory order = orders[orderId];
        return (order.customer, order.amount, order.timestamp, order.productId, order.status);
    }


    function getCustomerOrders(address customer, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory orderIds, uint256 total)
    {
        uint256[] memory customerOrderList = customerOrders[customer];
        total = customerOrderList.length;

        if (offset >= total) {
            return (new uint256[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 resultLength = end - offset;
        orderIds = new uint256[](resultLength);

        for (uint256 i = 0; i < resultLength;) {
            orderIds[i] = customerOrderList[offset + i];
            unchecked { ++i; }
        }
    }


    function getOrdersByStatus(OrderStatus status, uint256 maxResults)
        external
        view
        returns (uint256[] memory matchingOrders)
    {
        uint256[] memory tempOrders = new uint256[](maxResults);
        uint256 count = 0;


        uint256 maxOrderId = nextOrderId;

        for (uint256 i = 1; i < maxOrderId && count < maxResults;) {
            if (orders[i].status == status) {
                tempOrders[count] = i;
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }


        matchingOrders = new uint256[](count);
        for (uint256 i = 0; i < count;) {
            matchingOrders[i] = tempOrders[i];
            unchecked { ++i; }
        }
    }


    function getProductOrderCount(uint32 productId) external view returns (uint256) {
        return productOrderCount[productId];
    }


    function getContractStats() external view returns (uint256 total, uint256 nextId) {
        return (totalOrders, nextOrderId);
    }


    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }


    function pause() external onlyOwner {

    }

    receive() external payable {}
}
