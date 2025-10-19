
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
        bool isActive;
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
        address updatedBy
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address cancelledBy,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 _orderId) {
        require(
            msg.sender == orders[_orderId].buyer || msg.sender == orders[_orderId].seller,
            "Only buyer or seller can perform this action"
        );
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(orders[_orderId].isActive, "Order does not exist or is inactive");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address provided");
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
    )
        external
        validAddress(_seller)
        returns (uint256 orderId)
    {
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_quantity > 0, "Quantity must be greater than zero");
        require(_pricePerUnit > 0, "Price per unit must be greater than zero");


        uint256 totalAmount = _quantity * _pricePerUnit;


        orderId = nextOrderId;
        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            productName: _productName,
            quantity: _quantity,
            pricePerUnit: _pricePerUnit,
            totalAmount: totalAmount,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            isActive: true
        });


        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);


        nextOrderId++;
        totalOrders++;


        emit OrderCreated(orderId, msg.sender, _seller, _productName, totalAmount);

        return orderId;
    }


    function updateOrderStatus(uint256 _orderId, OrderStatus _newStatus)
        external
        orderExists(_orderId)
        onlyBuyerOrSeller(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.status != OrderStatus.Cancelled, "Cannot update cancelled order");
        require(order.status != _newStatus, "New status must be different from current status");


        require(isValidStatusTransition(order.status, _newStatus), "Invalid status transition");

        OrderStatus oldStatus = order.status;
        order.status = _newStatus;
        order.updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, _newStatus, msg.sender);
    }


    function cancelOrder(uint256 _orderId)
        external
        orderExists(_orderId)
        onlyBuyerOrSeller(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.status != OrderStatus.Cancelled, "Order is already cancelled");
        require(order.status != OrderStatus.Delivered, "Cannot cancel delivered order");

        OrderStatus oldStatus = order.status;
        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Cancelled, msg.sender);
        emit OrderCancelled(_orderId, msg.sender, block.timestamp);
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


    function getOrderCountByStatus(OrderStatus _status)
        external
        view
        returns (uint256 count)
    {
        count = 0;
        for (uint256 i = 1; i < nextOrderId; i++) {
            if (orders[i].isActive && orders[i].status == _status) {
                count++;
            }
        }
        return count;
    }


    function isValidStatusTransition(OrderStatus _currentStatus, OrderStatus _newStatus)
        internal
        pure
        returns (bool isValid)
    {
        if (_currentStatus == OrderStatus.Pending) {
            return _newStatus == OrderStatus.Confirmed || _newStatus == OrderStatus.Cancelled;
        } else if (_currentStatus == OrderStatus.Confirmed) {
            return _newStatus == OrderStatus.Shipped || _newStatus == OrderStatus.Cancelled;
        } else if (_currentStatus == OrderStatus.Shipped) {
            return _newStatus == OrderStatus.Delivered;
        }
        return false;
    }


    function emergencyStop() external onlyOwner {


    }


    function getContractInfo()
        external
        view
        returns (address owner, uint256 totalOrderCount, uint256 nextId)
    {
        return (contractOwner, totalOrders, nextOrderId);
    }
}
