
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
        uint256 refundAmount
    );

    event PaymentReceived(
        uint256 indexed orderId,
        address from,
        uint256 amount
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 _orderId) {
        require(
            msg.sender == orders[_orderId].buyer || msg.sender == orders[_orderId].seller,
            "Only buyer or seller can call this function"
        );
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(orders[_orderId].isActive, "Order does not exist or is inactive");
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
        uint256 _pricePerUnit
    )
        external
        payable
        validAddress(_seller)
        returns (uint256 orderId)
    {
        require(_seller != msg.sender, "Buyer and seller cannot be the same");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_quantity > 0, "Quantity must be greater than zero");
        require(_pricePerUnit > 0, "Price per unit must be greater than zero");

        uint256 totalAmount = _quantity * _pricePerUnit;
        require(msg.value >= totalAmount, "Insufficient payment amount");

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


        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit OrderCreated(orderId, msg.sender, _seller, _productName, totalAmount);
        emit PaymentReceived(orderId, msg.sender, totalAmount);

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


        if (_newStatus == OrderStatus.Confirmed) {
            require(
                msg.sender == order.seller && order.status == OrderStatus.Pending,
                "Only seller can confirm pending order"
            );
        } else if (_newStatus == OrderStatus.Shipped) {
            require(
                msg.sender == order.seller && order.status == OrderStatus.Confirmed,
                "Only seller can ship confirmed order"
            );
        } else if (_newStatus == OrderStatus.Delivered) {
            require(
                msg.sender == order.buyer && order.status == OrderStatus.Shipped,
                "Only buyer can confirm delivery of shipped order"
            );


            payable(order.seller).transfer(order.totalAmount);
        }

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


        if (oldStatus == OrderStatus.Pending || oldStatus == OrderStatus.Confirmed) {
            payable(order.buyer).transfer(order.totalAmount);
            emit OrderCancelled(_orderId, msg.sender, order.totalAmount);
        } else {
            emit OrderCancelled(_orderId, msg.sender, 0);
        }

        emit OrderStatusUpdated(_orderId, oldStatus, OrderStatus.Cancelled, msg.sender);
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
        returns (address owner, uint256 nextId, uint256 total)
    {
        return (contractOwner, nextOrderId, totalOrders);
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
