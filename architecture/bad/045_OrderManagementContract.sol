
pragma solidity ^0.8.0;

contract OrderManagementContract {


    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public isVendor;
    mapping(uint256 => bool) public orderExists;

    uint256 public orderCounter;
    address public owner;
    uint256 public totalRevenue;
    uint256 public totalOrders;

    struct Order {
        uint256 orderId;
        address buyer;
        address vendor;
        string productName;
        uint256 quantity;
        uint256 pricePerUnit;
        uint256 totalAmount;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        bool isPaid;
        string shippingAddress;
    }

    enum OrderStatus {
        Pending,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled,
        Refunded
    }

    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed vendor);
    event OrderConfirmed(uint256 indexed orderId);
    event OrderShipped(uint256 indexed orderId);
    event OrderDelivered(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event OrderRefunded(uint256 indexed orderId);
    event PaymentReceived(uint256 indexed orderId, uint256 amount);

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
        totalRevenue = 0;
        totalOrders = 0;
    }


    function addVendor(address _vendor) public {

        require(msg.sender == owner, "Only owner can add vendors");
        require(_vendor != address(0), "Invalid vendor address");

        isVendor[_vendor] = true;
    }


    function createOrder(
        address _buyer,
        string memory _productName,
        uint256 _quantity,
        uint256 _pricePerUnit,
        string memory _shippingAddress
    ) public {

        require(isVendor[msg.sender] == true, "Only vendors can create orders");
        require(_buyer != address(0), "Invalid buyer address");
        require(_quantity > 0, "Quantity must be greater than 0");
        require(_pricePerUnit > 0, "Price must be greater than 0");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(bytes(_shippingAddress).length > 0, "Shipping address cannot be empty");

        orderCounter++;
        uint256 totalAmount = _quantity * _pricePerUnit;

        orders[orderCounter] = Order({
            orderId: orderCounter,
            buyer: _buyer,
            vendor: msg.sender,
            productName: _productName,
            quantity: _quantity,
            pricePerUnit: _pricePerUnit,
            totalAmount: totalAmount,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            isPaid: false,
            shippingAddress: _shippingAddress
        });

        orderExists[orderCounter] = true;
        userOrders[_buyer].push(orderCounter);
        totalOrders++;

        emit OrderCreated(orderCounter, _buyer, msg.sender);
    }


    function confirmOrder(uint256 _orderId) public {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(orders[_orderId].vendor == msg.sender, "Only vendor can confirm order");
        require(orders[_orderId].status == OrderStatus.Pending, "Order is not pending");

        orders[_orderId].status = OrderStatus.Confirmed;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderConfirmed(_orderId);
    }


    function payForOrder(uint256 _orderId) public payable {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(orders[_orderId].buyer == msg.sender, "Only buyer can pay for order");
        require(orders[_orderId].status == OrderStatus.Confirmed, "Order must be confirmed first");
        require(orders[_orderId].isPaid == false, "Order already paid");
        require(msg.value == orders[_orderId].totalAmount, "Incorrect payment amount");

        orders[_orderId].isPaid = true;
        orders[_orderId].updatedAt = block.timestamp;
        totalRevenue += msg.value;


        uint256 platformFee = (msg.value * 10) / 100;
        uint256 vendorAmount = msg.value - platformFee;


        payable(orders[_orderId].vendor).transfer(vendorAmount);

        emit PaymentReceived(_orderId, msg.value);
    }


    function shipOrder(uint256 _orderId) public {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(orders[_orderId].vendor == msg.sender, "Only vendor can ship order");
        require(orders[_orderId].status == OrderStatus.Confirmed, "Order must be confirmed");
        require(orders[_orderId].isPaid == true, "Order must be paid");

        orders[_orderId].status = OrderStatus.Shipped;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderShipped(_orderId);
    }


    function deliverOrder(uint256 _orderId) public {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(orders[_orderId].buyer == msg.sender, "Only buyer can confirm delivery");
        require(orders[_orderId].status == OrderStatus.Shipped, "Order must be shipped first");

        orders[_orderId].status = OrderStatus.Delivered;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderDelivered(_orderId);
    }


    function cancelOrder(uint256 _orderId) public {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(
            orders[_orderId].buyer == msg.sender || orders[_orderId].vendor == msg.sender,
            "Only buyer or vendor can cancel order"
        );
        require(
            orders[_orderId].status == OrderStatus.Pending ||
            orders[_orderId].status == OrderStatus.Confirmed,
            "Cannot cancel shipped or delivered order"
        );


        if (orders[_orderId].status == OrderStatus.Confirmed) {
            require(
                block.timestamp <= orders[_orderId].updatedAt + 86400,
                "Cannot cancel after 24 hours of confirmation"
            );
        }

        orders[_orderId].status = OrderStatus.Cancelled;
        orders[_orderId].updatedAt = block.timestamp;


        if (orders[_orderId].isPaid) {
            payable(orders[_orderId].buyer).transfer(orders[_orderId].totalAmount);
            totalRevenue -= orders[_orderId].totalAmount;
        }

        emit OrderCancelled(_orderId);
    }


    function requestRefund(uint256 _orderId) public {

        require(orderExists[_orderId] == true, "Order does not exist");
        require(orders[_orderId].buyer == msg.sender, "Only buyer can request refund");
        require(orders[_orderId].isPaid == true, "Order must be paid");
        require(orders[_orderId].status == OrderStatus.Delivered, "Order must be delivered");


        require(
            block.timestamp <= orders[_orderId].updatedAt + 604800,
            "Refund period expired (7 days)"
        );

        orders[_orderId].status = OrderStatus.Refunded;
        orders[_orderId].updatedAt = block.timestamp;


        uint256 refundFee = (orders[_orderId].totalAmount * 5) / 100;
        uint256 refundAmount = orders[_orderId].totalAmount - refundFee;

        payable(orders[_orderId].buyer).transfer(refundAmount);
        totalRevenue -= orders[_orderId].totalAmount;

        emit OrderRefunded(_orderId);
    }


    function getOrdersByUser(address _user) public view returns (uint256[] memory) {
        return userOrders[_user];
    }


    function getOrderDetails(uint256 _orderId) public view returns (Order memory) {

        require(orderExists[_orderId] == true, "Order does not exist");
        return orders[_orderId];
    }


    function withdrawPlatformFees() public {

        require(msg.sender == owner, "Only owner can withdraw fees");

        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(owner).transfer(balance);
    }


    function updateOrderStatus(uint256 _orderId, OrderStatus _status) public {

        require(msg.sender == owner, "Only owner can update order status");

        require(orderExists[_orderId] == true, "Order does not exist");

        orders[_orderId].status = _status;
        orders[_orderId].updatedAt = block.timestamp;
    }


    function getTotalStats() public view returns (uint256, uint256, uint256) {
        return (totalOrders, totalRevenue, orderCounter);
    }


    function removeVendor(address _vendor) public {

        require(msg.sender == owner, "Only owner can remove vendors");
        require(_vendor != address(0), "Invalid vendor address");

        isVendor[_vendor] = false;
    }


    function searchOrdersByProduct(string memory _productName) public view returns (uint256[] memory) {
        uint256[] memory matchingOrders = new uint256[](orderCounter);
        uint256 count = 0;


        for (uint256 i = 1; i <= orderCounter; i++) {
            if (orderExists[i] &&
                keccak256(bytes(orders[i].productName)) == keccak256(bytes(_productName))) {
                matchingOrders[count] = i;
                count++;
            }
        }


        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = matchingOrders[j];
        }

        return result;
    }


    receive() external payable {

    }

    fallback() external payable {

    }
}
