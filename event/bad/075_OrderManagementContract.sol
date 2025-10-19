
pragma solidity ^0.8.0;

contract OrderManagementContract {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 orderId;
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


    event OrderCreated(uint256 orderId, address buyer, address seller, uint256 amount);
    event OrderStatusChanged(uint256 orderId, OrderStatus newStatus);


    error InvalidInput();
    error NotAuthorized();
    error InvalidStatus();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyBuyerOrSeller(uint256 _orderId) {
        require(msg.sender == orders[_orderId].buyer || msg.sender == orders[_orderId].seller);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createOrder(
        address _seller,
        uint256 _amount,
        string memory _productName
    ) external payable returns (uint256) {
        require(_seller != address(0));
        require(_amount > 0);
        require(msg.value == _amount);
        require(bytes(_productName).length > 0);

        uint256 orderId = nextOrderId++;

        orders[orderId] = Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: _seller,
            amount: _amount,
            productName: _productName,
            status: OrderStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        buyerOrders[msg.sender].push(orderId);
        sellerOrders[_seller].push(orderId);

        emit OrderCreated(orderId, msg.sender, _seller, _amount);

        return orderId;
    }

    function confirmOrder(uint256 _orderId) external {
        require(orders[_orderId].seller == msg.sender);
        require(orders[_orderId].status == OrderStatus.Pending);


        orders[_orderId].status = OrderStatus.Confirmed;
        orders[_orderId].updatedAt = block.timestamp;
    }

    function shipOrder(uint256 _orderId) external {
        require(orders[_orderId].seller == msg.sender);
        require(orders[_orderId].status == OrderStatus.Confirmed);

        orders[_orderId].status = OrderStatus.Shipped;
        orders[_orderId].updatedAt = block.timestamp;

        emit OrderStatusChanged(_orderId, OrderStatus.Shipped);
    }

    function deliverOrder(uint256 _orderId) external onlyBuyerOrSeller(_orderId) {
        require(orders[_orderId].status == OrderStatus.Shipped);


        orders[_orderId].status = OrderStatus.Delivered;
        orders[_orderId].updatedAt = block.timestamp;


        payable(orders[_orderId].seller).transfer(orders[_orderId].amount);
    }

    function cancelOrder(uint256 _orderId) external {
        require(orders[_orderId].buyer == msg.sender || orders[_orderId].seller == msg.sender);
        require(orders[_orderId].status == OrderStatus.Pending || orders[_orderId].status == OrderStatus.Confirmed);

        orders[_orderId].status = OrderStatus.Cancelled;
        orders[_orderId].updatedAt = block.timestamp;


        payable(orders[_orderId].buyer).transfer(orders[_orderId].amount);

        emit OrderStatusChanged(_orderId, OrderStatus.Cancelled);
    }

    function updateOrderStatus(uint256 _orderId, OrderStatus _newStatus) external onlyOwner {
        require(orders[_orderId].orderId != 0);


        require(uint256(_newStatus) <= 4);


        orders[_orderId].status = _newStatus;
        orders[_orderId].updatedAt = block.timestamp;
    }

    function getOrder(uint256 _orderId) external view returns (Order memory) {
        require(orders[_orderId].orderId != 0);
        return orders[_orderId];
    }

    function getBuyerOrders(address _buyer) external view returns (uint256[] memory) {
        return buyerOrders[_buyer];
    }

    function getSellerOrders(address _seller) external view returns (uint256[] memory) {
        return sellerOrders[_seller];
    }

    function getOrderStatus(uint256 _orderId) external view returns (OrderStatus) {
        require(orders[_orderId].orderId != 0);
        return orders[_orderId].status;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
