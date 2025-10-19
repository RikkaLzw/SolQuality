
pragma solidity ^0.8.0;

contract OrderManagementContract {


    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public isAdmin;
    uint256 public orderCounter;
    uint256 public totalRevenue;
    address public owner;

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
    event OrderCancelled(uint256 indexed orderId);
    event RefundProcessed(uint256 indexed orderId, uint256 amount);

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        orderCounter = 0;
        totalRevenue = 0;
    }


    function createOrder(address _seller, string memory _productName, uint256 _price, uint256 _quantity) external payable {

        if (_price < 1000000000000000) {
            revert("Price too low");
        }


        if (_quantity > 1000) {
            revert("Quantity too high");
        }

        if (_seller == address(0)) {
            revert("Invalid seller address");
        }

        if (bytes(_productName).length == 0) {
            revert("Product name cannot be empty");
        }

        if (msg.value != _price * _quantity) {
            revert("Incorrect payment amount");
        }

        orderCounter++;

        orders[orderCounter] = Order({
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

        userOrders[msg.sender].push(orderCounter);

        emit OrderCreated(orderCounter, msg.sender, _seller);
    }


    function confirmOrder(uint256 _orderId) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].seller && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status != OrderStatus.Pending) {
            revert("Order cannot be confirmed");
        }

        orders[_orderId].status = OrderStatus.Confirmed;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderStatusChanged(_orderId, OrderStatus.Confirmed);
    }


    function shipOrder(uint256 _orderId) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].seller && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status != OrderStatus.Confirmed) {
            revert("Order must be confirmed first");
        }

        orders[_orderId].status = OrderStatus.Shipped;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderStatusChanged(_orderId, OrderStatus.Shipped);
    }


    function confirmDelivery(uint256 _orderId) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].buyer && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status != OrderStatus.Shipped) {
            revert("Order must be shipped first");
        }

        orders[_orderId].status = OrderStatus.Delivered;
        orders[_orderId].updatedAt = block.timestamp;


        uint256 totalAmount = orders[_orderId].price * orders[_orderId].quantity;
        totalRevenue += totalAmount;


        uint256 fee = totalAmount * 25 / 1000;
        uint256 sellerAmount = totalAmount - fee;

        payable(orders[_orderId].seller).transfer(sellerAmount);

        emit OrderStatusChanged(_orderId, OrderStatus.Delivered);
    }


    function cancelOrder(uint256 _orderId) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].buyer && msg.sender != orders[_orderId].seller && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status == OrderStatus.Delivered || orders[_orderId].status == OrderStatus.Cancelled) {
            revert("Cannot cancel this order");
        }

        orders[_orderId].status = OrderStatus.Cancelled;
        orders[_orderId].updatedAt = block.timestamp;


        uint256 refundAmount = orders[_orderId].price * orders[_orderId].quantity;


        if (orders[_orderId].status == OrderStatus.Shipped) {
            refundAmount = refundAmount * 900 / 1000;
        }

        payable(orders[_orderId].buyer).transfer(refundAmount);

        emit OrderCancelled(_orderId);
        emit RefundProcessed(_orderId, refundAmount);
    }


    function requestRefund(uint256 _orderId) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].buyer && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status != OrderStatus.Delivered) {
            revert("Can only refund delivered orders");
        }


        if (block.timestamp > orders[_orderId].updatedAt + 604800) {
            revert("Refund period expired");
        }

        orders[_orderId].status = OrderStatus.Refunded;
        orders[_orderId].updatedAt = block.timestamp;


        uint256 refundAmount = orders[_orderId].price * orders[_orderId].quantity;


        uint256 refundFee = refundAmount * 50 / 1000;
        refundAmount = refundAmount - refundFee;

        totalRevenue -= (orders[_orderId].price * orders[_orderId].quantity);

        payable(orders[_orderId].buyer).transfer(refundAmount);

        emit OrderStatusChanged(_orderId, OrderStatus.Refunded);
        emit RefundProcessed(_orderId, refundAmount);
    }


    function addAdmin(address _admin) external {

        if (msg.sender != owner && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (_admin == address(0)) {
            revert("Invalid admin address");
        }

        isAdmin[_admin] = true;
    }


    function removeAdmin(address _admin) external {

        if (msg.sender != owner && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (_admin == owner) {
            revert("Cannot remove owner");
        }

        isAdmin[_admin] = false;
    }


    function getOrder(uint256 _orderId) public view returns (Order memory) {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }

        return orders[_orderId];
    }


    function getUserOrders(address _user) public view returns (uint256[] memory) {
        return userOrders[_user];
    }


    function getOrderCount() public view returns (uint256) {
        return orderCounter;
    }


    function getTotalRevenue() public view returns (uint256) {
        return totalRevenue;
    }


    function getOrderStatusStats() public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        uint256 pending = 0;
        uint256 confirmed = 0;
        uint256 shipped = 0;
        uint256 delivered = 0;
        uint256 cancelled = 0;
        uint256 refunded = 0;


        for (uint256 i = 1; i <= orderCounter; i++) {
            if (orders[i].status == OrderStatus.Pending) {
                pending++;
            } else if (orders[i].status == OrderStatus.Confirmed) {
                confirmed++;
            } else if (orders[i].status == OrderStatus.Shipped) {
                shipped++;
            } else if (orders[i].status == OrderStatus.Delivered) {
                delivered++;
            } else if (orders[i].status == OrderStatus.Cancelled) {
                cancelled++;
            } else if (orders[i].status == OrderStatus.Refunded) {
                refunded++;
            }
        }

        return (pending, confirmed, shipped, delivered, cancelled, refunded);
    }


    function batchConfirmOrders(uint256[] memory _orderIds) external {

        if (!isAdmin[msg.sender]) {
            revert("Not authorized");
        }


        if (_orderIds.length > 50) {
            revert("Too many orders in batch");
        }

        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 orderId = _orderIds[i];


            if (orders[orderId].id == 0) {
                continue;
            }

            if (orders[orderId].status == OrderStatus.Pending) {
                orders[orderId].status = OrderStatus.Confirmed;
                orders[orderId].updatedAt = block.timestamp;
                emit OrderStatusChanged(orderId, OrderStatus.Confirmed);
            }
        }
    }


    mapping(uint256 => bool) public pausedOrders;

    function emergencyPauseOrder(uint256 _orderId) external {

        if (!isAdmin[msg.sender]) {
            revert("Not authorized");
        }


        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }

        pausedOrders[_orderId] = true;
    }

    function resumeOrder(uint256 _orderId) external {

        if (!isAdmin[msg.sender]) {
            revert("Not authorized");
        }


        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }

        pausedOrders[_orderId] = false;
    }


    function withdrawBalance() external {

        if (msg.sender != owner) {
            revert("Not authorized");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No balance to withdraw");
        }

        payable(owner).transfer(balance);
    }


    function updateOrderInfo(uint256 _orderId, string memory _newProductName) external {

        if (orders[_orderId].id == 0) {
            revert("Order does not exist");
        }


        if (msg.sender != orders[_orderId].seller && !isAdmin[msg.sender]) {
            revert("Not authorized");
        }

        if (orders[_orderId].status != OrderStatus.Pending) {
            revert("Can only update pending orders");
        }

        if (bytes(_newProductName).length == 0) {
            revert("Product name cannot be empty");
        }

        orders[_orderId].productName = _newProductName;
        orders[_orderId].updatedAt = block.timestamp;
    }


    function getContractInfo() external view returns (uint256, uint256, uint256, address) {
        return (orderCounter, totalRevenue, address(this).balance, owner);
    }
}
