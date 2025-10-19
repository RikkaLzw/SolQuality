
pragma solidity ^0.8.0;

contract OrderManagementContract {


    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    uint256 public orderCounter;
    address public owner;
    uint256 public totalRevenue;
    mapping(address => bool) public authorizedSellers;

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
    event PaymentProcessed(uint256 indexed orderId, uint256 amount);

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
        totalRevenue = 0;
    }


    function addAuthorizedSeller(address seller) external {

        require(msg.sender == owner, "Only owner can add sellers");
        require(seller != address(0), "Invalid seller address");
        authorizedSellers[seller] = true;
    }


    function removeAuthorizedSeller(address seller) external {

        require(msg.sender == owner, "Only owner can remove sellers");
        require(seller != address(0), "Invalid seller address");
        authorizedSellers[seller] = false;
    }


    function createOrder(
        address seller,
        string memory productName,
        uint256 price,
        uint256 quantity
    ) external payable {

        require(seller != address(0), "Invalid seller address");
        require(bytes(productName).length > 0, "Product name cannot be empty");
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");
        require(authorizedSellers[seller], "Seller not authorized");


        uint256 totalPrice = price * quantity;
        require(msg.value >= totalPrice, "Insufficient payment");


        orderCounter = orderCounter + 1;
        uint256 orderId = orderCounter;


        Order memory newOrder = Order({
            id: orderId,
            buyer: msg.sender,
            seller: seller,
            productName: productName,
            price: price,
            quantity: quantity,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        orders[orderId] = newOrder;
        userOrders[msg.sender].push(orderId);


        uint256 platformFee = totalPrice * 5 / 100;
        uint256 sellerAmount = totalPrice - platformFee;

        totalRevenue = totalRevenue + platformFee;


        payable(seller).transfer(sellerAmount);


        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit OrderCreated(orderId, msg.sender, seller);
        emit PaymentProcessed(orderId, totalPrice);
    }


    function confirmOrder(uint256 orderId) external {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order storage order = orders[orderId];
        require(order.seller == msg.sender, "Only seller can confirm order");
        require(order.status == OrderStatus.Pending, "Order not in pending status");


        order.status = OrderStatus.Confirmed;
        order.updatedAt = block.timestamp;

        emit OrderStatusChanged(orderId, OrderStatus.Confirmed);
    }


    function shipOrder(uint256 orderId) external {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order storage order = orders[orderId];
        require(order.seller == msg.sender, "Only seller can ship order");
        require(order.status == OrderStatus.Confirmed, "Order not confirmed");


        order.status = OrderStatus.Shipped;
        order.updatedAt = block.timestamp;

        emit OrderStatusChanged(orderId, OrderStatus.Shipped);
    }


    function deliverOrder(uint256 orderId) external {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order storage order = orders[orderId];
        require(order.buyer == msg.sender, "Only buyer can confirm delivery");
        require(order.status == OrderStatus.Shipped, "Order not shipped");


        order.status = OrderStatus.Delivered;
        order.updatedAt = block.timestamp;

        emit OrderStatusChanged(orderId, OrderStatus.Delivered);
    }


    function cancelOrder(uint256 orderId) external {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order storage order = orders[orderId];
        require(order.buyer == msg.sender || order.seller == msg.sender, "Not authorized to cancel");
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed, "Cannot cancel order");


        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        uint256 totalPrice = order.price * order.quantity;
        uint256 platformFee = totalPrice * 5 / 100;
        uint256 refundAmount = totalPrice - platformFee;


        if (address(this).balance >= refundAmount) {
            payable(order.buyer).transfer(refundAmount);
            totalRevenue = totalRevenue - platformFee;
        }

        emit OrderStatusChanged(orderId, OrderStatus.Cancelled);
    }


    function processRefund(uint256 orderId) external {

        require(msg.sender == owner, "Only owner can process refunds");

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.Delivered || order.status == OrderStatus.Cancelled, "Invalid status for refund");


        order.status = OrderStatus.Refunded;
        order.updatedAt = block.timestamp;


        uint256 totalPrice = order.price * order.quantity;
        uint256 platformFee = totalPrice * 5 / 100;
        uint256 refundAmount = totalPrice - platformFee;

        if (address(this).balance >= refundAmount) {
            payable(order.buyer).transfer(refundAmount);
            totalRevenue = totalRevenue - platformFee;
        }

        emit OrderStatusChanged(orderId, OrderStatus.Refunded);
    }


    function getOrder(uint256 orderId) public view returns (Order memory) {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        return orders[orderId];
    }


    function getUserOrders(address user) public view returns (uint256[] memory) {
        return userOrders[user];
    }


    function withdrawRevenue() external {
        require(msg.sender == owner, "Only owner can withdraw revenue");
        require(totalRevenue > 0, "No revenue to withdraw");

        uint256 amount = totalRevenue;
        totalRevenue = 0;
        payable(owner).transfer(amount);
    }


    function updateOwner(address newOwner) external {
        require(msg.sender == owner, "Only owner can update owner");
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }


    function calculatePlatformFee(uint256 amount) public pure returns (uint256) {

        return amount * 5 / 100;
    }


    function calculateSellerAmount(uint256 totalPrice) public pure returns (uint256) {

        uint256 platformFee = totalPrice * 5 / 100;
        return totalPrice - platformFee;
    }


    function getOrderStatus(uint256 orderId) external view returns (OrderStatus) {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        return orders[orderId].status;
    }


    function getOrderTotal(uint256 orderId) external view returns (uint256) {

        require(orderId > 0 && orderId <= orderCounter, "Invalid order ID");
        Order memory order = orders[orderId];

        return order.price * order.quantity;
    }


    function isValidOrder(uint256 orderId) public view returns (bool) {
        return orderId > 0 && orderId <= orderCounter;
    }


    function isAuthorizedSeller(address seller) public view returns (bool) {
        return authorizedSellers[seller];
    }


    receive() external payable {}


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
