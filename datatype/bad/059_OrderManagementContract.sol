
pragma solidity ^0.8.0;

contract OrderManagementContract {

    uint256 public constant MAX_QUANTITY = 100;
    uint256 public constant MIN_QUANTITY = 1;


    struct Order {
        string orderId;
        address buyer;
        address seller;
        uint256 quantity;
        uint256 price;
        uint256 status;
        string productName;
        bytes metadata;
        uint256 timestamp;
        uint256 isActive;
    }

    mapping(string => Order) public orders;
    mapping(address => string[]) public userOrders;


    string[] public allOrderIds;

    uint256 public totalOrders;
    address public owner;


    uint256 public contractActive;

    event OrderCreated(string indexed orderId, address indexed buyer, address indexed seller);
    event OrderStatusChanged(string indexed orderId, uint256 newStatus);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier contractIsActive() {
        require(contractActive == 1, "Contract is paused");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = 1;
        totalOrders = 0;
    }

    function createOrder(
        string memory _orderId,
        address _seller,
        uint256 _quantity,
        uint256 _price,
        string memory _productName,
        bytes memory _metadata
    ) public contractIsActive {
        require(_seller != address(0), "Invalid seller address");
        require(_quantity >= MIN_QUANTITY && _quantity <= MAX_QUANTITY, "Invalid quantity");
        require(_price > 0, "Price must be greater than 0");
        require(orders[_orderId].isActive == 0, "Order already exists");


        uint256 convertedQuantity = uint256(_quantity);
        uint256 convertedPrice = uint256(_price);

        orders[_orderId] = Order({
            orderId: _orderId,
            buyer: msg.sender,
            seller: _seller,
            quantity: convertedQuantity,
            price: convertedPrice,
            status: 0,
            productName: _productName,
            metadata: _metadata,
            timestamp: block.timestamp,
            isActive: 1
        });

        userOrders[msg.sender].push(_orderId);
        userOrders[_seller].push(_orderId);
        allOrderIds.push(_orderId);

        totalOrders++;

        emit OrderCreated(_orderId, msg.sender, _seller);
    }

    function confirmOrder(string memory _orderId) public {
        Order storage order = orders[_orderId];
        require(order.isActive == 1, "Order not found or inactive");
        require(msg.sender == order.seller, "Only seller can confirm order");
        require(order.status == 0, "Order already processed");


        uint256 newStatus = uint256(1);
        order.status = newStatus;

        emit OrderStatusChanged(_orderId, newStatus);
    }

    function shipOrder(string memory _orderId) public {
        Order storage order = orders[_orderId];
        require(order.isActive == 1, "Order not found or inactive");
        require(msg.sender == order.seller, "Only seller can ship order");
        require(order.status == 1, "Order must be confirmed first");

        order.status = 2;

        emit OrderStatusChanged(_orderId, 2);
    }

    function deliverOrder(string memory _orderId) public {
        Order storage order = orders[_orderId];
        require(order.isActive == 1, "Order not found or inactive");
        require(msg.sender == order.buyer, "Only buyer can confirm delivery");
        require(order.status == 2, "Order must be shipped first");

        order.status = 3;

        emit OrderStatusChanged(_orderId, 3);
    }

    function cancelOrder(string memory _orderId) public {
        Order storage order = orders[_orderId];
        require(order.isActive == 1, "Order not found or inactive");
        require(msg.sender == order.buyer || msg.sender == order.seller, "Only buyer or seller can cancel");
        require(order.status < 2, "Cannot cancel shipped or delivered order");

        order.status = 4;

        emit OrderStatusChanged(_orderId, 4);
    }

    function getOrder(string memory _orderId) public view returns (Order memory) {
        require(orders[_orderId].isActive == 1, "Order not found or inactive");
        return orders[_orderId];
    }

    function getUserOrders(address _user) public view returns (string[] memory) {
        return userOrders[_user];
    }

    function getAllOrderIds() public view returns (string[] memory) {
        return allOrderIds;
    }

    function updateOrderMetadata(string memory _orderId, bytes memory _newMetadata) public {
        Order storage order = orders[_orderId];
        require(order.isActive == 1, "Order not found or inactive");
        require(msg.sender == order.seller, "Only seller can update metadata");

        order.metadata = _newMetadata;
    }

    function pauseContract() public onlyOwner {
        contractActive = 0;
    }

    function resumeContract() public onlyOwner {
        contractActive = 1;
    }

    function getOrderStatus(string memory _orderId) public view returns (uint256) {
        require(orders[_orderId].isActive == 1, "Order not found or inactive");
        return orders[_orderId].status;
    }

    function isOrderActive(string memory _orderId) public view returns (uint256) {

        return orders[_orderId].isActive;
    }

    function getTotalActiveOrders() public view returns (uint256) {

        uint256 activeCount = 0;

        for (uint256 i = 0; i < allOrderIds.length; i++) {

            uint256 index = uint256(i);
            string memory orderId = allOrderIds[index];

            if (orders[orderId].isActive == 1) {
                activeCount++;
            }
        }

        return activeCount;
    }
}
