
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
    mapping(address => uint256[]) public userOrders;
    uint256 public nextOrderId;
    address public owner;


    event OrderCreated(uint256 orderId, address buyer, address seller, uint256 amount);
    event OrderStatusChanged(uint256 orderId, OrderStatus newStatus);
    event PaymentReceived(uint256 orderId, uint256 amount);


    error InvalidInput();
    error NotAuthorized();
    error OrderNotFound();

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
        nextOrderId = 1;
    }

    function createOrder(
        address _seller,
        string memory _productName
    ) external payable returns (uint256) {
        require(msg.value > 0);
        require(_seller != address(0));
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

        userOrders[msg.sender].push(orderId);
        userOrders[_seller].push(orderId);

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

        emit OrderStatusChanged(_orderId, OrderStatus.Confirmed);
    }

    function shipOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.id != 0);
        require(msg.sender == order.seller);
        require(order.status == OrderStatus.Confirmed);

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


        payable(order.seller).transfer(order.amount);

        emit OrderStatusChanged(_orderId, OrderStatus.Delivered);
    }

    function cancelOrder(uint256 _orderId) external onlyBuyerOrSeller(_orderId) {
        Order storage order = orders[_orderId];
        require(order.id != 0);
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed);

        order.status = OrderStatus.Cancelled;
        order.updatedAt = block.timestamp;


        if (order.status == OrderStatus.Pending || order.status == OrderStatus.Confirmed) {
            payable(order.buyer).transfer(order.amount);
        }

        emit OrderStatusChanged(_orderId, OrderStatus.Cancelled);
    }

    function updateOrderAmount(uint256 _orderId, uint256 _newAmount) external onlyOwner {
        Order storage order = orders[_orderId];
        if (order.id == 0) {

            revert OrderNotFound();
        }


        order.amount = _newAmount;
        order.updatedAt = block.timestamp;
    }

    function getOrder(uint256 _orderId) external view returns (Order memory) {
        Order memory order = orders[_orderId];
        require(order.id != 0);
        return order;
    }

    function getUserOrders(address _user) external view returns (uint256[] memory) {
        return userOrders[_user];
    }

    function getOrderCount() external view returns (uint256) {
        return nextOrderId - 1;
    }

    function emergencyWithdraw() external onlyOwner {

        payable(owner).transfer(address(this).balance);
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));


        owner = _newOwner;
    }

    receive() external payable {

    }
}
