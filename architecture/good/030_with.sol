
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract OrderManagementContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant MAX_ORDER_AMOUNT = 1000000 ether;
    uint256 public constant MIN_ORDER_AMOUNT = 0.001 ether;
    uint256 public constant ORDER_EXPIRY_DURATION = 30 days;
    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant BASIS_POINTS = 10000;


    Counters.Counter private _orderIdCounter;
    mapping(uint256 => Order) private _orders;
    mapping(address => uint256[]) private _userOrders;
    mapping(address => bool) public authorizedOperators;

    uint256 public totalOrdersCreated;
    uint256 public totalOrdersCompleted;
    uint256 public totalPlatformFees;


    enum OrderStatus {
        Created,
        Confirmed,
        Processing,
        Shipped,
        Delivered,
        Cancelled,
        Refunded
    }

    enum OrderType {
        Purchase,
        Service,
        Subscription
    }


    struct Order {
        uint256 id;
        address buyer;
        address seller;
        OrderType orderType;
        OrderStatus status;
        uint256 amount;
        uint256 platformFee;
        uint256 createdAt;
        uint256 expiresAt;
        string description;
        bool exists;
    }


    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        OrderType orderType,
        uint256 amount,
        string description
    );

    event OrderStatusUpdated(
        uint256 indexed orderId,
        OrderStatus previousStatus,
        OrderStatus newStatus,
        address updatedBy
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed cancelledBy,
        uint256 refundAmount
    );

    event PlatformFeesWithdrawn(
        address indexed owner,
        uint256 amount
    );

    event OperatorAuthorized(address indexed operator, bool authorized);


    modifier validOrderId(uint256 orderId) {
        require(_orders[orderId].exists, "Order does not exist");
        _;
    }

    modifier onlyBuyerOrSeller(uint256 orderId) {
        Order memory order = _orders[orderId];
        require(
            msg.sender == order.buyer || msg.sender == order.seller,
            "Only buyer or seller can perform this action"
        );
        _;
    }

    modifier onlyAuthorizedOperator() {
        require(
            authorizedOperators[msg.sender] || msg.sender == owner(),
            "Not authorized operator"
        );
        _;
    }

    modifier validAmount() {
        require(
            msg.value >= MIN_ORDER_AMOUNT && msg.value <= MAX_ORDER_AMOUNT,
            "Invalid order amount"
        );
        _;
    }

    modifier notExpired(uint256 orderId) {
        require(
            block.timestamp <= _orders[orderId].expiresAt,
            "Order has expired"
        );
        _;
    }

    modifier inStatus(uint256 orderId, OrderStatus expectedStatus) {
        require(
            _orders[orderId].status == expectedStatus,
            "Invalid order status for this operation"
        );
        _;
    }

    constructor() {
        authorizedOperators[msg.sender] = true;
    }


    function createOrder(
        address seller,
        OrderType orderType,
        string memory description
    )
        external
        payable
        validAmount
        nonReentrant
    {
        require(seller != address(0), "Invalid seller address");
        require(seller != msg.sender, "Buyer and seller cannot be the same");
        require(bytes(description).length > 0, "Description cannot be empty");

        _orderIdCounter.increment();
        uint256 orderId = _orderIdCounter.current();

        uint256 platformFee = _calculatePlatformFee(msg.value);

        Order memory newOrder = Order({
            id: orderId,
            buyer: msg.sender,
            seller: seller,
            orderType: orderType,
            status: OrderStatus.Created,
            amount: msg.value,
            platformFee: platformFee,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + ORDER_EXPIRY_DURATION,
            description: description,
            exists: true
        });

        _orders[orderId] = newOrder;
        _userOrders[msg.sender].push(orderId);
        _userOrders[seller].push(orderId);

        totalOrdersCreated++;
        totalPlatformFees += platformFee;

        emit OrderCreated(orderId, msg.sender, seller, orderType, msg.value, description);
    }


    function updateOrderStatus(uint256 orderId, OrderStatus newStatus)
        external
        validOrderId(orderId)
        notExpired(orderId)
        nonReentrant
    {
        Order storage order = _orders[orderId];

        require(
            msg.sender == order.seller ||
            msg.sender == order.buyer ||
            authorizedOperators[msg.sender] ||
            msg.sender == owner(),
            "Not authorized to update status"
        );

        OrderStatus previousStatus = order.status;
        require(_isValidStatusTransition(previousStatus, newStatus), "Invalid status transition");

        order.status = newStatus;

        if (newStatus == OrderStatus.Delivered) {
            _completeOrder(orderId);
        }

        emit OrderStatusUpdated(orderId, previousStatus, newStatus, msg.sender);
    }


    function cancelOrder(uint256 orderId)
        external
        validOrderId(orderId)
        onlyBuyerOrSeller(orderId)
        nonReentrant
    {
        Order storage order = _orders[orderId];

        require(
            order.status == OrderStatus.Created ||
            order.status == OrderStatus.Confirmed,
            "Cannot cancel order in current status"
        );

        order.status = OrderStatus.Cancelled;

        uint256 refundAmount = order.amount;


        (bool success, ) = payable(order.buyer).call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit OrderCancelled(orderId, msg.sender, refundAmount);
    }


    function getOrder(uint256 orderId)
        external
        view
        validOrderId(orderId)
        returns (Order memory)
    {
        return _orders[orderId];
    }


    function getUserOrders(address user)
        external
        view
        returns (uint256[] memory)
    {
        return _userOrders[user];
    }


    function setOperatorAuthorization(address operator, bool authorized)
        external
        onlyOwner
    {
        require(operator != address(0), "Invalid operator address");
        authorizedOperators[operator] = authorized;
        emit OperatorAuthorized(operator, authorized);
    }


    function withdrawPlatformFees()
        external
        onlyOwner
        nonReentrant
    {
        uint256 amount = totalPlatformFees;
        require(amount > 0, "No fees to withdraw");

        totalPlatformFees = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Fee withdrawal failed");

        emit PlatformFeesWithdrawn(owner(), amount);
    }


    function getContractStats()
        external
        view
        returns (
            uint256 ordersCreated,
            uint256 ordersCompleted,
            uint256 platformFees,
            uint256 contractBalance
        )
    {
        return (
            totalOrdersCreated,
            totalOrdersCompleted,
            totalPlatformFees,
            address(this).balance
        );
    }


    function _calculatePlatformFee(uint256 amount) internal pure returns (uint256) {
        return (amount * PLATFORM_FEE_RATE) / BASIS_POINTS;
    }

    function _completeOrder(uint256 orderId) internal {
        Order storage order = _orders[orderId];

        uint256 sellerAmount = order.amount - order.platformFee;


        (bool success, ) = payable(order.seller).call{value: sellerAmount}("");
        require(success, "Payment transfer to seller failed");

        totalOrdersCompleted++;
    }

    function _isValidStatusTransition(OrderStatus from, OrderStatus to)
        internal
        pure
        returns (bool)
    {
        if (from == OrderStatus.Created) {
            return to == OrderStatus.Confirmed || to == OrderStatus.Cancelled;
        }
        if (from == OrderStatus.Confirmed) {
            return to == OrderStatus.Processing || to == OrderStatus.Cancelled;
        }
        if (from == OrderStatus.Processing) {
            return to == OrderStatus.Shipped || to == OrderStatus.Cancelled;
        }
        if (from == OrderStatus.Shipped) {
            return to == OrderStatus.Delivered;
        }
        if (from == OrderStatus.Cancelled) {
            return to == OrderStatus.Refunded;
        }
        return false;
    }


    function emergencyPause() external onlyOwner {

    }

    receive() external payable {
        revert("Direct payments not accepted");
    }

    fallback() external {
        revert("Function not found");
    }
}
