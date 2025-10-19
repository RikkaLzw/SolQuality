
pragma solidity ^0.8.0;

contract OrderManagementContract {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 id;
        address buyer;
        address seller;
        uint256 amount;
        string productName;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256[]) public sellerOrders;

    uint256 public nextOrderId = 1;
    address public owner;
    uint256 public platformFee = 25;


    event OrderCreated(uint256 orderId, address buyer, address seller, uint256 amount);
    event OrderStatusChanged(uint256 orderId, OrderStatus newStatus);
    event PaymentProcessed(uint256 orderId, uint256 amount);


    error InvalidInput();
    error NotAuthorized();
    error OrderNotFound();
    error WrongStatus();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier onlyBuyerOrSeller(uint256 _orderId) {
        Order storage order = orders[_orderId];

        require(msg.sender == order.buyer || msg.sender == order.seller);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createOrder(
        address _seller,
        string memory _productName
    ) external payable returns (uint256) {

        require(msg.value > 0);
        require(_seller != address(0));
        require(_seller != msg.sender);
        require(bytes(_productName).length > 0);

        uint256 orderId = nextOrderId++;

        orders[orderId] = Order({
            id: orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            productName: _productName,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, msg.value);

        return orderId;
    }

    function confirmOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];


        require(order.id != 0);
        require(msg.sender == order.seller);
        require(order.status == OrderStatus.Pending);

        order.status = OrderStatus.Confirmed;

        order.updatedAt = block.timestamp;
    }

    function shipOrder(uint256 _orderId) external onlyBuyerOrSeller(_orderId) {
        Order storage order = orders[_orderId];


        require(order.status == OrderStatus.Confirmed);
        require(msg.sender == order.seller);

        order.status = OrderStatus.Shipped;
        order.updatedAt = block.timestamp;

        emit OrderStatusChanged(_orderId, OrderStatus.Shipped);
    }

    function deliverOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];


        require(order.id != 0);
        require(msg.sender == order.buyer);
        require(order.status == OrderStatus.Shipped);

        order.status = OrderStatus.Delivered;
        order.updatedAt = block.timestamp;


        uint256 fee = (order.amount * platformFee) / 1000;
        uint256 sellerAmount = order.amount - fee;


        payable(order.seller).transfer(sellerAmount);


        emit PaymentProcessed(_orderId, sellerAmount);
        emit OrderStatusChanged(_orderId, OrderStatus.Delivered);
    }

    function cancelOrder(uint256 _orderId) external onlyBuyerOrSeller(_orderId) {
        Order storage order = orders[_orderId];


        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed);

        if (msg.sender == order.buyer) {

        } else if (msg.sender == order.seller) {

            require(order.status == OrderStatus.Pending);
        }

        order.status = OrderStatus.Cancelled;

        order.updatedAt = block.timestamp;


        payable(order.buyer).transfer(order.amount);
    }

    function getOrder(uint256 _orderId) external view returns (Order memory) {

        require(orders[_orderId].id != 0);
        return orders[_orderId];
    }

    function getBuyerOrders(address _buyer) external view returns (uint256[] memory) {
        return buyerOrders[_buyer];
    }

    function getSellerOrders(address _seller) external view returns (uint256[] memory) {
        return sellerOrders[_seller];
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {

        require(_newFee <= 100);

        platformFee = _newFee;

    }

    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);

        payable(owner).transfer(balance);
    }

    function emergencyPause() external onlyOwner {


    }

    function getContractBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }
}
