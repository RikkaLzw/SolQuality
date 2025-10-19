
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library OrderLibrary {
    struct Order {
        uint256 id;
        address buyer;
        address seller;
        uint256 amount;
        uint256 price;
        uint256 createdAt;
        uint256 deadline;
        OrderStatus status;
        string description;
    }

    enum OrderStatus {
        Created,
        Confirmed,
        Shipped,
        Delivered,
        Cancelled,
        Disputed
    }

    function calculateTotalValue(Order memory order) internal pure returns (uint256) {
        return order.amount * order.price;
    }

    function isOrderActive(Order memory order) internal pure returns (bool) {
        return order.status == OrderStatus.Created ||
               order.status == OrderStatus.Confirmed ||
               order.status == OrderStatus.Shipped;
    }

    function isOrderExpired(Order memory order) internal view returns (bool) {
        return block.timestamp > order.deadline;
    }
}

abstract contract OrderBase is Ownable, ReentrancyGuard, Pausable {
    using OrderLibrary for OrderLibrary.Order;


    uint256 public constant MIN_ORDER_AMOUNT = 1;
    uint256 public constant MAX_ORDER_AMOUNT = 1000000;
    uint256 public constant MIN_DEADLINE_DURATION = 1 days;
    uint256 public constant MAX_DEADLINE_DURATION = 365 days;
    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant BASIS_POINTS = 10000;


    uint256 internal _orderCounter;
    mapping(uint256 => OrderLibrary.Order) internal _orders;
    mapping(address => uint256[]) internal _userOrders;
    mapping(address => mapping(address => bool)) internal _authorizedOperators;


    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event OrderStatusChanged(uint256 indexed orderId, OrderLibrary.OrderStatus oldStatus, OrderLibrary.OrderStatus newStatus);
    event OrderCancelled(uint256 indexed orderId, address indexed canceller);
    event PaymentProcessed(uint256 indexed orderId, uint256 amount, uint256 fee);
    event OperatorAuthorized(address indexed user, address indexed operator, bool authorized);


    modifier validOrderId(uint256 orderId) {
        require(orderId > 0 && orderId <= _orderCounter, "Invalid order ID");
        _;
    }

    modifier onlyOrderParty(uint256 orderId) {
        OrderLibrary.Order storage order = _orders[orderId];
        require(
            msg.sender == order.buyer ||
            msg.sender == order.seller ||
            _authorizedOperators[order.buyer][msg.sender] ||
            _authorizedOperators[order.seller][msg.sender],
            "Not authorized for this order"
        );
        _;
    }

    modifier onlyBuyer(uint256 orderId) {
        require(_orders[orderId].buyer == msg.sender, "Only buyer can perform this action");
        _;
    }

    modifier onlySeller(uint256 orderId) {
        require(_orders[orderId].seller == msg.sender, "Only seller can perform this action");
        _;
    }

    modifier orderInStatus(uint256 orderId, OrderLibrary.OrderStatus status) {
        require(_orders[orderId].status == status, "Order not in required status");
        _;
    }

    modifier notExpired(uint256 orderId) {
        require(!_orders[orderId].isOrderExpired(), "Order has expired");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount >= MIN_ORDER_AMOUNT && amount <= MAX_ORDER_AMOUNT, "Invalid order amount");
        _;
    }

    modifier validDeadline(uint256 deadline) {
        require(
            deadline > block.timestamp + MIN_DEADLINE_DURATION &&
            deadline < block.timestamp + MAX_DEADLINE_DURATION,
            "Invalid deadline"
        );
        _;
    }


    function _generateOrderId() internal returns (uint256) {
        _orderCounter++;
        return _orderCounter;
    }

    function _calculatePlatformFee(uint256 totalValue) internal pure returns (uint256) {
        return (totalValue * PLATFORM_FEE_RATE) / BASIS_POINTS;
    }

    function _updateOrderStatus(uint256 orderId, OrderLibrary.OrderStatus newStatus) internal {
        OrderLibrary.Order storage order = _orders[orderId];
        OrderLibrary.OrderStatus oldStatus = order.status;
        order.status = newStatus;
        emit OrderStatusChanged(orderId, oldStatus, newStatus);
    }

    function _addOrderToUser(address user, uint256 orderId) internal {
        _userOrders[user].push(orderId);
    }
}

contract OrderManagementContract is OrderBase {
    using OrderLibrary for OrderLibrary.Order;


    mapping(uint256 => uint256) private _escrowBalances;
    mapping(address => uint256) private _userBalances;
    uint256 private _platformBalance;

    constructor() {
        _transferOwnership(msg.sender);
    }


    function createOrder(
        address seller,
        uint256 amount,
        uint256 price,
        uint256 deadline,
        string calldata description
    )
        external
        payable
        whenNotPaused
        nonReentrant
        validAmount(amount)
        validDeadline(deadline)
        returns (uint256)
    {
        require(seller != address(0) && seller != msg.sender, "Invalid seller address");
        require(price > 0, "Price must be greater than zero");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 totalValue = amount * price;
        uint256 platformFee = _calculatePlatformFee(totalValue);
        uint256 requiredPayment = totalValue + platformFee;

        require(msg.value >= requiredPayment, "Insufficient payment");

        uint256 orderId = _generateOrderId();

        _orders[orderId] = OrderLibrary.Order({
            id: orderId,
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            price: price,
            createdAt: block.timestamp,
            deadline: deadline,
            status: OrderLibrary.OrderStatus.Created,
            description: description
        });

        _escrowBalances[orderId] = totalValue;
        _platformBalance += platformFee;

        _addOrderToUser(msg.sender, orderId);
        _addOrderToUser(seller, orderId);


        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }

        emit OrderCreated(orderId, msg.sender, seller, amount, price);
        emit PaymentProcessed(orderId, totalValue, platformFee);

        return orderId;
    }


    function confirmOrder(uint256 orderId)
        external
        whenNotPaused
        validOrderId(orderId)
        onlySeller(orderId)
        orderInStatus(orderId, OrderLibrary.OrderStatus.Created)
        notExpired(orderId)
    {
        _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Confirmed);
    }


    function markAsShipped(uint256 orderId)
        external
        whenNotPaused
        validOrderId(orderId)
        onlySeller(orderId)
        orderInStatus(orderId, OrderLibrary.OrderStatus.Confirmed)
        notExpired(orderId)
    {
        _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Shipped);
    }


    function confirmDelivery(uint256 orderId)
        external
        whenNotPaused
        nonReentrant
        validOrderId(orderId)
        onlyBuyer(orderId)
        orderInStatus(orderId, OrderLibrary.OrderStatus.Shipped)
    {
        OrderLibrary.Order storage order = _orders[orderId];
        uint256 escrowAmount = _escrowBalances[orderId];

        _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Delivered);
        _escrowBalances[orderId] = 0;


        _userBalances[order.seller] += escrowAmount;

        emit PaymentProcessed(orderId, escrowAmount, 0);
    }


    function cancelOrder(uint256 orderId)
        external
        whenNotPaused
        nonReentrant
        validOrderId(orderId)
        onlyOrderParty(orderId)
    {
        OrderLibrary.Order storage order = _orders[orderId];
        require(
            order.status == OrderLibrary.OrderStatus.Created ||
            order.isOrderExpired(),
            "Cannot cancel order in current status"
        );

        uint256 escrowAmount = _escrowBalances[orderId];

        _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Cancelled);
        _escrowBalances[orderId] = 0;


        if (escrowAmount > 0) {
            _userBalances[order.buyer] += escrowAmount;
        }

        emit OrderCancelled(orderId, msg.sender);
    }


    function raiseDispute(uint256 orderId)
        external
        whenNotPaused
        validOrderId(orderId)
        onlyOrderParty(orderId)
    {
        OrderLibrary.Order storage order = _orders[orderId];
        require(order.isOrderActive(), "Order is not active");

        _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Disputed);
    }


    function resolveDispute(uint256 orderId, bool favorBuyer)
        external
        onlyOwner
        nonReentrant
        validOrderId(orderId)
        orderInStatus(orderId, OrderLibrary.OrderStatus.Disputed)
    {
        OrderLibrary.Order storage order = _orders[orderId];
        uint256 escrowAmount = _escrowBalances[orderId];

        _escrowBalances[orderId] = 0;

        if (favorBuyer) {
            _userBalances[order.buyer] += escrowAmount;
            _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Cancelled);
        } else {
            _userBalances[order.seller] += escrowAmount;
            _updateOrderStatus(orderId, OrderLibrary.OrderStatus.Delivered);
        }

        emit PaymentProcessed(orderId, escrowAmount, 0);
    }


    function setOperatorAuthorization(address operator, bool authorized) external {
        require(operator != address(0), "Invalid operator address");
        require(operator != msg.sender, "Cannot authorize yourself");

        _authorizedOperators[msg.sender][operator] = authorized;
        emit OperatorAuthorized(msg.sender, operator, authorized);
    }


    function withdrawBalance() external nonReentrant {
        uint256 balance = _userBalances[msg.sender];
        require(balance > 0, "No balance to withdraw");

        _userBalances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        uint256 balance = _platformBalance;
        require(balance > 0, "No platform fees to withdraw");

        _platformBalance = 0;
        payable(owner()).transfer(balance);
    }


    function getOrder(uint256 orderId)
        external
        view
        validOrderId(orderId)
        returns (OrderLibrary.Order memory)
    {
        return _orders[orderId];
    }

    function getUserOrders(address user) external view returns (uint256[] memory) {
        return _userOrders[user];
    }

    function getUserBalance(address user) external view returns (uint256) {
        return _userBalances[user];
    }

    function getEscrowBalance(uint256 orderId) external view returns (uint256) {
        return _escrowBalances[orderId];
    }

    function getPlatformBalance() external view onlyOwner returns (uint256) {
        return _platformBalance;
    }

    function getTotalOrders() external view returns (uint256) {
        return _orderCounter;
    }

    function isAuthorizedOperator(address user, address operator) external view returns (bool) {
        return _authorizedOperators[user][operator];
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
