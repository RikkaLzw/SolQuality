
pragma solidity ^0.8.0;

contract OrderManagementContract {


    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public isAdmin;
    uint256 public orderCounter;
    uint256 public totalRevenue;
    address public owner;
    bool public contractActive;

    struct Order {
        uint256 id;
        address buyer;
        address seller;
        string productName;
        uint256 price;
        uint256 quantity;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    enum OrderStatus {
        Pending,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled,
        Refunded
    }

    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller);
    event OrderStatusChanged(uint256 indexed orderId, OrderStatus newStatus);
    event PaymentReceived(uint256 indexed orderId, uint256 amount);

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        orderCounter = 0;
        totalRevenue = 0;
        contractActive = true;
    }


    function createOrder(
        address _seller,
        string memory _productName,
        uint256 _price,
        uint256 _quantity
    ) public payable {

        require(_price >= 1000000000000000, "Price too low");
        require(_quantity > 0, "Quantity must be positive");
        require(bytes(_productName).length > 0, "Product name required");
        require(_seller != address(0), "Invalid seller address");
        require(_seller != msg.sender, "Cannot create order for yourself");
        require(contractActive == true, "Contract is not active");
        require(msg.value >= _price * _quantity, "Insufficient payment");

        orderCounter++;

        Order memory newOrder = Order({
            id: orderCounter,
            buyer: msg.sender,
            seller: _seller,
            productName: _productName,
            price: _price,
            quantity: _quantity,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        orders[orderCounter] = newOrder;
        userOrders[msg.sender].push(orderCounter);
        userOrders[_seller].push(orderCounter);

        emit OrderCreated(orderCounter, msg.sender, _seller);
        emit PaymentReceived(orderCounter, msg.value);
    }


    function confirmOrder(uint256 _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");

        Order storage order = orders[_orderId];
        require(order.seller == msg.sender || isAdmin[msg.sender] == true, "Not authorized");
        require(order.status == OrderStatus.Pending, "Order not in pending status");


        order.status = OrderStatus.Confirmed;
        order.updatedAt = block.timestamp;
        orders[_orderId] = order;

        emit OrderStatusChanged(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(uint256 _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");

        Order storage order = orders[_orderId];
        require(order.seller == msg.sender || isAdmin[msg.sender] == true, "Not authorized");
        require(order.status == OrderStatus.Confirmed, "Order not confirmed");


        order.status = OrderStatus.Shipped;
        order.updatedAt = block.timestamp;
        orders[_orderId] = order;

        emit OrderStatusChanged(_orderId, OrderStatus.Shipped);
    }


    function deliverOrder(uint256 _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");

        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender || isAdmin[msg.sender] == true, "Not authorized");
        require(order.status == OrderStatus.Shipped, "Order not shipped");


        order.status = OrderStatus.Delivered;
        order.updatedAt = block.timestamp;
        orders[_orderId] = order;


        uint256 fee = (order.price * order.quantity * 5) / 100;
        uint256 sellerAmount = (order.price * order.quantity) - fee;

        totalRevenue += fee;

        payable(order.seller).transfer(sellerAmount);

        emit OrderStatusChanged(_orderId, OrderStatus.Delivered);
    }


    function cancelOrder(uint256 _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");

        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender || order.seller == msg.sender || isAdmin[msg.sender] == true, "Not authorized");
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed, "Cannot cancel order");


        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;
        orders[_orderId] = order;


        uint256 refundAmount = order.price * order.quantity;
        payable(order.buyer).transfer(refundAmount);

        emit OrderStatusChanged(_orderId, OrderStatus.Cancelled);
    }


    function refundOrder(uint256 _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");

        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender || isAdmin[msg.sender] == true, "Not authorized");
        require(order.status == OrderStatus.Delivered, "Order not delivered");


        require(block.timestamp <= order.updatedAt + 604800, "Refund period expired");


        order.status = OrderStatus.Refunded;
        order.updatedAt = block.timestamp;
        orders[_orderId] = order;


        uint256 refundFee = (order.price * order.quantity * 10) / 100;
        uint256 refundAmount = (order.price * order.quantity) - refundFee;

        totalRevenue += refundFee;

        payable(order.buyer).transfer(refundAmount);

        emit OrderStatusChanged(_orderId, OrderStatus.Refunded);
    }


    function batchConfirmOrders(uint256[] memory _orderIds) public {
        require(isAdmin[msg.sender] == true, "Only admin can batch process");
        require(contractActive == true, "Contract is not active");

        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 orderId = _orderIds[i];
            require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");

            Order storage order = orders[orderId];
            if (order.status == OrderStatus.Pending) {
                order.status = OrderStatus.Confirmed;
                order.updatedAt = block.timestamp;
                orders[orderId] = order;
                emit OrderStatusChanged(orderId, OrderStatus.Confirmed);
            }
        }
    }


    function batchShipOrders(uint256[] memory _orderIds) public {
        require(isAdmin[msg.sender] == true, "Only admin can batch process");
        require(contractActive == true, "Contract is not active");

        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 orderId = _orderIds[i];
            require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");

            Order storage order = orders[orderId];
            if (order.status == OrderStatus.Confirmed) {
                order.status = OrderStatus.Shipped;
                order.updatedAt = block.timestamp;
                orders[orderId] = order;
                emit OrderStatusChanged(orderId, OrderStatus.Shipped);
            }
        }
    }


    function getUserOrders(address _user) public view returns (uint256[] memory) {
        require(_user != address(0), "Invalid user address");
        require(contractActive == true, "Contract is not active");
        return userOrders[_user];
    }


    function getOrderDetails(uint256 _orderId) public view returns (Order memory) {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");
        return orders[_orderId];
    }


    function getOrderStatus(uint256 _orderId) public view returns (OrderStatus) {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(contractActive == true, "Contract is not active");
        return orders[_orderId].status;
    }


    function addAdmin(address _admin) public {
        require(msg.sender == owner, "Only owner can add admin");
        require(_admin != address(0), "Invalid admin address");
        require(contractActive == true, "Contract is not active");
        isAdmin[_admin] = true;
    }


    function removeAdmin(address _admin) public {
        require(msg.sender == owner, "Only owner can remove admin");
        require(_admin != address(0), "Invalid admin address");
        require(_admin != owner, "Cannot remove owner");
        require(contractActive == true, "Contract is not active");
        isAdmin[_admin] = false;
    }


    function pauseContract() public {
        require(msg.sender == owner, "Only owner can pause");
        require(contractActive == true, "Contract already paused");
        contractActive = false;
    }


    function resumeContract() public {
        require(msg.sender == owner, "Only owner can resume");
        require(contractActive == false, "Contract already active");
        contractActive = true;
    }


    function withdrawRevenue() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(contractActive == true, "Contract is not active");
        require(totalRevenue > 0, "No revenue to withdraw");

        uint256 amount = totalRevenue;
        totalRevenue = 0;
        payable(owner).transfer(amount);
    }


    function emergencyWithdraw() public {
        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(address(this).balance > 0, "No balance to withdraw");

        payable(owner).transfer(address(this).balance);
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getTotalRevenue() public view returns (uint256) {
        return totalRevenue;
    }


    function getTotalOrders() public view returns (uint256) {
        return orderCounter;
    }


    function checkAdmin(address _user) public view returns (bool) {
        return isAdmin[_user];
    }


    receive() external payable {}


    fallback() external payable {}
}
