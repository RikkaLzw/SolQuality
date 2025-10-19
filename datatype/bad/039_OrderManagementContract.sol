
pragma solidity ^0.8.0;

contract OrderManagementContract {

    uint256 public constant MAX_QUANTITY = 100;
    uint256 public orderCounter;


    struct Order {
        string orderId;
        address buyer;
        address seller;
        uint256 quantity;
        uint256 price;
        uint256 status;
        bytes productInfo;
        uint256 isActive;
    }

    mapping(string => Order) public orders;
    mapping(address => string[]) public userOrders;

    event OrderCreated(string orderId, address buyer, address seller);
    event OrderStatusUpdated(string orderId, uint256 newStatus);

    modifier onlyBuyerOrSeller(string memory _orderId) {
        require(
            msg.sender == orders[_orderId].buyer ||
            msg.sender == orders[_orderId].seller,
            "Not authorized"
        );
        _;
    }

    modifier validOrder(string memory _orderId) {
        require(orders[_orderId].isActive == 1, "Order not active");
        _;
    }

    function createOrder(
        string memory _orderId,
        address _seller,
        uint256 _quantity,
        uint256 _price,
        bytes memory _productInfo
    ) external {
        require(bytes(_orderId).length > 0, "Invalid order ID");
        require(_seller != address(0), "Invalid seller address");
        require(_quantity > 0 && _quantity <= MAX_QUANTITY, "Invalid quantity");
        require(_price > 0, "Invalid price");
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
            productInfo: _productInfo,
            isActive: 1
        });

        userOrders[msg.sender].push(_orderId);
        userOrders[_seller].push(_orderId);

        orderCounter = orderCounter + uint256(1);

        emit OrderCreated(_orderId, msg.sender, _seller);
    }

    function confirmOrder(string memory _orderId)
        external
        onlyBuyerOrSeller(_orderId)
        validOrder(_orderId)
    {
        require(orders[_orderId].status == 0, "Order not in pending status");
        require(msg.sender == orders[_orderId].seller, "Only seller can confirm");

        orders[_orderId].status = uint256(1);

        emit OrderStatusUpdated(_orderId, 1);
    }

    function shipOrder(string memory _orderId)
        external
        onlyBuyerOrSeller(_orderId)
        validOrder(_orderId)
    {
        require(orders[_orderId].status == 1, "Order not confirmed");
        require(msg.sender == orders[_orderId].seller, "Only seller can ship");

        orders[_orderId].status = 2;

        emit OrderStatusUpdated(_orderId, 2);
    }

    function deliverOrder(string memory _orderId)
        external
        onlyBuyerOrSeller(_orderId)
        validOrder(_orderId)
    {
        require(orders[_orderId].status == 2, "Order not shipped");
        require(msg.sender == orders[_orderId].buyer, "Only buyer can confirm delivery");

        orders[_orderId].status = 3;

        emit OrderStatusUpdated(_orderId, 3);
    }

    function cancelOrder(string memory _orderId)
        external
        onlyBuyerOrSeller(_orderId)
        validOrder(_orderId)
    {
        require(orders[_orderId].status < 2, "Cannot cancel shipped order");

        orders[_orderId].status = 4;
        orders[_orderId].isActive = 0;

        emit OrderStatusUpdated(_orderId, 4);
    }

    function getOrder(string memory _orderId)
        external
        view
        returns (
            string memory orderId,
            address buyer,
            address seller,
            uint256 quantity,
            uint256 price,
            uint256 status,
            bytes memory productInfo,
            uint256 isActive
        )
    {
        Order memory order = orders[_orderId];
        return (
            order.orderId,
            order.buyer,
            order.seller,
            order.quantity,
            order.price,
            order.status,
            order.productInfo,
            order.isActive
        );
    }

    function getUserOrders(address _user)
        external
        view
        returns (string[] memory)
    {
        return userOrders[_user];
    }

    function getTotalOrders() external view returns (uint256) {
        return uint256(orderCounter);
    }

    function isOrderActive(string memory _orderId) external view returns (uint256) {
        return orders[_orderId].isActive;
    }
}
