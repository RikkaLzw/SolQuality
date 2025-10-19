
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
        uint256 unitPrice;
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


    modifier onlyOwner() {
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

    modifier orderExists(uint256 _orderId) {
        require(_orderId < nextOrderId && orders[_orderId].orderId == _orderId, "Order does not exist");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
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
        uint256 _unitPrice
    )
        external
        validAddress(_seller)
        returns (uint256 orderId)
    {
        require(_quantity > 0, "Quantity must be greater than zero");
        require(_unitPrice > 0, "Unit price must be greater than zero");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_seller != msg.sender, "Seller cannot be the same as buyer");


        uint256 totalAmount = _quantity * _unitPrice;


        orderId = nextOrderId;
        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            productName: _productName,
            quantity: _quantity,
            unitPrice: _unitPrice,
            totalAmount: totalAmount,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            isPaid: false
        });


        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);
        nextOrderId++;
        totalOrders++;


        emit OrderCreated(orderId, msg.sender, _seller, _productName, totalAmount);

        return orderId;
    }


    function payOrder(uint256 _orderId)
        external
        payable
        orderExists(_orderId)
        onlyBuyer(_orderId)
    {
        Order storage order = orders[_orderId];

        require(order.status == OrderStatus.Pending, "Order is not in pending status");
        require(!order.isPaid, "Order is already paid");
        require(msg.value == order.totalAmount, "Payment amount does not match order total");


        order.isPaid = true;
        order.status = OrderStatus.Confirmed;
        order.updatedAt = block.timestamp;


        emit OrderPaid(_orderId, msg.sender, msg.value);
        emit OrderStatusUpdated(_orderId, OrderStatus.Pending, OrderStatus.Confirmed, block.timestamp);
    }


    function updateOrderStatus(uint256 _orderId, OrderStatus _newStatus)
        external
        orderExists(_orderId)
        onlySeller(_orderId)
    {
        Order storage order = orders[_orderId];
        OrderStatus oldStatus = order.status;

        require(oldStatus != OrderStatus.Cancelled, "Cannot update cancelled order");
        require(_newStatus != OrderStatus.Pending, "Cannot set status back to pending");
        require(_newStatus != OrderStatus.Cancelled, "Use cancelOrder function to cancel");
        require(oldStatus != _newStatus, "New status must be different from current status");


        if (_newStatus == OrderStatus.Shipped) {
            require(oldStatus == OrderStatus.Confirmed, "Order must be confirmed before shipping");
        } else if (_newStatus == OrderStatus.Delivered) {
            require(oldStatus == OrderStatus.Shipped, "Order must be shipped before delivery");
        }


        order.status = _newStatus;
        order.updatedAt = block.timestamp;


        if (_newStatus == OrderStatus.Delivered && order.isPaid) {
            payable(order.seller).transfer(order.totalAmount);
        }


        emit OrderStatusUpdated(_orderId, oldStatus, _newStatus, block.timestamp);
    }


    function cancelOrder(uint256 _orderId)
        external
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];

        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Only buyer or seller can cancel the order"
        );
        require(order.status != OrderStatus.Cancelled, "Order is already cancelled");
        require(order.status != OrderStatus.Delivered, "Cannot cancel delivered order");

        OrderStatus oldStatus = order.status;


        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        if (order.isPaid && order.status != OrderStatus.Delivered) {
            payable(order.buyer).transfer(order.totalAmount);
        }


        emit OrderCancelled(_orderId, msg.sender, block.timestamp);
        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Cancelled, block.timestamp);
    }


    function getOrder(uint256 _orderId)
        external
        view
        orderExists(_orderId)
        returns (Order memory order)
    {
        return orders[_orderId];
    }


    function getBuyerOrders(address _buyer)
        external
        view
        validAddress(_buyer)
        returns (uint256[] memory orderIds)
    {
        return buyerOrders[_buyer];
    }


    function getSellerOrders(address _seller)
        external
        view
        validAddress(_seller)
        returns (uint256[] memory orderIds)
    {
        return sellerOrders[_seller];
    }


    function getContractInfo()
        external
        view
        returns (uint256 nextId, uint256 total, address owner)
    {
        return (nextOrderId, totalOrders, contractOwner);
    }


    function emergencyWithdraw()
        external
        onlyOwner
    {
        payable(contractOwner).transfer(address(this).balance);
    }


    function getContractBalance()
        external
        view
        returns (uint256 balance)
    {
        return address(this).balance;
    }
}
