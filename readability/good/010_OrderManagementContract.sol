
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
        uint256 orderId;
        address buyer;
        address seller;
        string productName;
        uint256 quantity;
        uint256 pricePerUnit;
        uint256 totalAmount;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        bool isPaid;
    }


    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256[]) public sellerOrders;

    uint256 public nextOrderId;
    uint256 public totalOrders;
    address public contractOwner;


    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        string productName,
        uint256 totalAmount
    );

    event OrderStatusUpdated(
        uint256 indexed orderId,
        OrderStatus oldStatus,
        OrderStatus newStatus,
        uint256 timestamp
    );

    event OrderPaid(
        uint256 indexed orderId,
        address indexed buyer,
        uint256 amount
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed cancelledBy,
        uint256 timestamp
    );

    event OrderCompleted(
        uint256 indexed orderId,
        uint256 timestamp
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyBuyer(uint256 _orderId) {
        require(orders[_orderId].buyer == msg.sender, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(uint256 _orderId) {
        require(orders[_orderId].seller == msg.sender, "Only seller can call this function");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 _orderId) {
        require(
            orders[_orderId].buyer == msg.sender || orders[_orderId].seller == msg.sender,
            "Only buyer or seller can call this function"
        );
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(_orderId < nextOrderId && orders[_orderId].orderId == _orderId, "Order does not exist");
        _;
    }

    modifier validOrderStatus(uint256 _orderId, OrderStatus _expectedStatus) {
        require(orders[_orderId].status == _expectedStatus, "Invalid order status for this operation");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        nextOrderId = 1;
        totalOrders = 0;
    }


    function createOrder(
        address _seller,
        string memory _productName,
        uint256 _quantity,
        uint256 _pricePerUnit
    ) external {
        require(_seller != address(0), "Invalid seller address");
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_quantity > 0, "Quantity must be greater than zero");
        require(_pricePerUnit > 0, "Price per unit must be greater than zero");

        uint256 totalAmount = _quantity * _pricePerUnit;
        uint256 currentOrderId = nextOrderId;


        orders[currentOrderId] = Order({
            orderId: currentOrderId,
            buyer: msg.sender,
            seller: _seller,
            productName: _productName,
            quantity: _quantity,
            pricePerUnit: _pricePerUnit,
            totalAmount: totalAmount,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            isPaid: false
        });


        buyerOrders[msg.sender].push(currentOrderId);
        sellerOrders[_seller].push(currentOrderId);


        nextOrderId++;
        totalOrders++;


        emit OrderCreated(currentOrderId, msg.sender, _seller, _productName, totalAmount);
    }


    function payOrder(uint256 _orderId)
        external
        payable
        orderExists(_orderId)
        onlyBuyer(_orderId)
        validOrderStatus(_orderId, OrderStatus.Pending)
    {
        Order storage order = orders[_orderId];
        require(msg.value == order.totalAmount, "Payment amount does not match order total");
        require(!order.isPaid, "Order is already paid");


        order.isPaid = true;
        order.status = OrderStatus.Confirmed;
        order.updatedAt = block.timestamp;


        emit OrderPaid(_orderId, msg.sender, msg.value);
        emit OrderStatusUpdated(_orderId, OrderStatus.Pending, OrderStatus.Confirmed, block.timestamp);
    }


    function shipOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
        validOrderStatus(_orderId, OrderStatus.Confirmed)
    {
        Order storage order = orders[_orderId];
        require(order.isPaid, "Order must be paid before shipping");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Shipped;
        order.updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Shipped, block.timestamp);
    }


    function confirmDelivery(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyBuyer(_orderId)
        validOrderStatus(_orderId, OrderStatus.Shipped)
    {
        Order storage order = orders[_orderId];
        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Delivered;
        order.updatedAt = block.timestamp;


        payable(order.seller).transfer(order.totalAmount);

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Delivered, block.timestamp);
        emit OrderCompleted(_orderId, block.timestamp);
    }


    function cancelOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyBuyerOrSeller(_orderId)
    {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed,
            "Cannot cancel order in current status"
        );

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        if (order.isPaid) {
            payable(order.buyer).transfer(order.totalAmount);
        }

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Cancelled, block.timestamp);
        emit OrderCancelled(_orderId, msg.sender, block.timestamp);
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
        return buyerOrders[_buyer];
    }


    function getSellerOrders(address _seller)
        external
        view
        returns (uint256[] memory)
    {
        return sellerOrders[_seller];
    }


    function getContractBalance()
        external
        view
        onlyContractOwner
        returns (uint256)
    {
        return address(this).balance;
    }


    function emergencyWithdraw()
        external
        onlyContractOwner
    {
        payable(contractOwner).transfer(address(this).balance);
    }


    function getOrderStatusString(OrderStatus _status)
        external
        pure
        returns (string memory)
    {
        if (_status == OrderStatus.Pending) return "Pending";
        if (_status == OrderStatus.Confirmed) return "Confirmed";
        if (_status == OrderStatus.Shipped) return "Shipped";
        if (_status == OrderStatus.Delivered) return "Delivered";
        if (_status == OrderStatus.Cancelled) return "Cancelled";
        return "Unknown";
    }
}
