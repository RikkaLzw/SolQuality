
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library OrderLib {
    struct Order {
        uint256 orderId;
        address buyer;
        address seller;
        uint256 amount;
        uint256 price;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    enum OrderStatus {
        Created,
        Confirmed,
        Shipped,
        Delivered,
        Completed,
        Cancelled,
        Disputed
    }

    function calculateTotalPrice(Order memory order) internal pure returns (uint256) {
        return order.amount * order.price;
    }

    function isValidTransition(OrderStatus from, OrderStatus to) internal pure returns (bool) {
        if (from == OrderStatus.Created) {
            return to == OrderStatus.Confirmed || to == OrderStatus.Cancelled;
        } else if (from == OrderStatus.Confirmed) {
            return to == OrderStatus.Shipped || to == OrderStatus.Cancelled || to == OrderStatus.Disputed;
        } else if (from == OrderStatus.Shipped) {
            return to == OrderStatus.Delivered || to == OrderStatus.Disputed;
        } else if (from == OrderStatus.Delivered) {
            return to == OrderStatus.Completed || to == OrderStatus.Disputed;
        } else if (from == OrderStatus.Disputed) {
            return to == OrderStatus.Completed || to == OrderStatus.Cancelled;
        }
        return false;
    }
}

abstract contract OrderBase is Ownable, ReentrancyGuard, Pausable {
    using OrderLib for OrderLib.Order;


    uint256 public constant MAX_ORDER_AMOUNT = 1000000;
    uint256 public constant MIN_ORDER_PRICE = 1 wei;
    uint256 public constant ORDER_TIMEOUT = 30 days;
    uint256 public constant DISPUTE_TIMEOUT = 7 days;


    mapping(uint256 => OrderLib.Order) internal _orders;
    mapping(address => uint256[]) internal _userOrders;
    mapping(address => bool) internal _authorizedSellers;

    uint256 internal _orderCounter;
    uint256 internal _platformFeeRate = 250;
    address internal _feeRecipient;


    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event OrderStatusChanged(uint256 indexed orderId, OrderLib.OrderStatus oldStatus, OrderLib.OrderStatus newStatus);
    event OrderCompleted(uint256 indexed orderId, uint256 totalAmount, uint256 platformFee);
    event OrderCancelled(uint256 indexed orderId, string reason);
    event SellerAuthorized(address indexed seller);
    event SellerRevoked(address indexed seller);
    event PlatformFeeUpdated(uint256 oldRate, uint256 newRate);


    modifier onlyOrderParticipant(uint256 orderId) {
        OrderLib.Order memory order = _orders[orderId];
        require(
            msg.sender == order.buyer || msg.sender == order.seller || msg.sender == owner(),
            "OrderBase: Not authorized for this order"
        );
        _;
    }

    modifier orderExists(uint256 orderId) {
        require(_orders[orderId].orderId != 0, "OrderBase: Order does not exist");
        _;
    }

    modifier onlyAuthorizedSeller() {
        require(_authorizedSellers[msg.sender], "OrderBase: Not an authorized seller");
        _;
    }

    modifier validOrderParams(uint256 amount, uint256 price) {
        require(amount > 0 && amount <= MAX_ORDER_AMOUNT, "OrderBase: Invalid amount");
        require(price >= MIN_ORDER_PRICE, "OrderBase: Invalid price");
        _;
    }

    modifier notExpired(uint256 orderId) {
        OrderLib.Order memory order = _orders[orderId];
        require(
            block.timestamp <= order.createdAt + ORDER_TIMEOUT,
            "OrderBase: Order has expired"
        );
        _;
    }

    constructor(address feeRecipient) {
        require(feeRecipient != address(0), "OrderBase: Invalid fee recipient");
        _feeRecipient = feeRecipient;
    }

    function _updateOrderStatus(uint256 orderId, OrderLib.OrderStatus newStatus) internal {
        OrderLib.Order storage order = _orders[orderId];
        OrderLib.OrderStatus oldStatus = order.status;

        require(
            OrderLib.isValidTransition(oldStatus, newStatus),
            "OrderBase: Invalid status transition"
        );

        order.status = newStatus;
        order.updatedAt = block.timestamp;

        emit OrderStatusChanged(orderId, oldStatus, newStatus);
    }

    function _calculatePlatformFee(uint256 totalPrice) internal view returns (uint256) {
        return (totalPrice * _platformFeeRate) / 10000;
    }

    function getOrder(uint256 orderId) external view orderExists(orderId) returns (OrderLib.Order memory) {
        return _orders[orderId];
    }

    function getUserOrders(address user) external view returns (uint256[] memory) {
        return _userOrders[user];
    }

    function isAuthorizedSeller(address seller) external view returns (bool) {
        return _authorizedSellers[seller];
    }

    function getPlatformFeeRate() external view returns (uint256) {
        return _platformFeeRate;
    }
}

contract OrderManagementContract is OrderBase {
    mapping(uint256 => uint256) private _orderDeposits;
    mapping(uint256 => uint256) private _disputeDeadlines;

    event PaymentDeposited(uint256 indexed orderId, uint256 amount);
    event PaymentReleased(uint256 indexed orderId, address indexed recipient, uint256 amount);
    event DisputeRaised(uint256 indexed orderId, address indexed initiator);
    event DisputeResolved(uint256 indexed orderId, address indexed winner);

    modifier hasDeposit(uint256 orderId) {
        require(_orderDeposits[orderId] > 0, "OrderManagement: No deposit found");
        _;
    }

    modifier onlyBuyer(uint256 orderId) {
        require(msg.sender == _orders[orderId].buyer, "OrderManagement: Only buyer allowed");
        _;
    }

    modifier onlySeller(uint256 orderId) {
        require(msg.sender == _orders[orderId].seller, "OrderManagement: Only seller allowed");
        _;
    }

    constructor(address feeRecipient) OrderBase(feeRecipient) {}

    function createOrder(
        address seller,
        uint256 amount,
        uint256 price
    ) external payable whenNotPaused validOrderParams(amount, price) nonReentrant returns (uint256) {
        require(_authorizedSellers[seller], "OrderManagement: Seller not authorized");
        require(msg.sender != seller, "OrderManagement: Cannot create order with yourself");

        uint256 totalPrice = amount * price;
        uint256 platformFee = _calculatePlatformFee(totalPrice);
        uint256 requiredDeposit = totalPrice + platformFee;

        require(msg.value >= requiredDeposit, "OrderManagement: Insufficient payment");

        _orderCounter++;
        uint256 orderId = _orderCounter;

        _orders[orderId] = OrderLib.Order({
            orderId: orderId,
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            price: price,
            status: OrderLib.OrderStatus.Created,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        _orderDeposits[orderId] = requiredDeposit;
        _userOrders[msg.sender].push(orderId);
        _userOrders[seller].push(orderId);

        if (msg.value > requiredDeposit) {
            payable(msg.sender).transfer(msg.value - requiredDeposit);
        }

        emit OrderCreated(orderId, msg.sender, seller, amount, price);
        emit PaymentDeposited(orderId, requiredDeposit);

        return orderId;
    }

    function confirmOrder(uint256 orderId)
        external
        orderExists(orderId)
        onlySeller(orderId)
        notExpired(orderId)
        whenNotPaused
    {
        require(_orders[orderId].status == OrderLib.OrderStatus.Created, "OrderManagement: Invalid order status");
        _updateOrderStatus(orderId, OrderLib.OrderStatus.Confirmed);
    }

    function shipOrder(uint256 orderId)
        external
        orderExists(orderId)
        onlySeller(orderId)
        whenNotPaused
    {
        require(_orders[orderId].status == OrderLib.OrderStatus.Confirmed, "OrderManagement: Order not confirmed");
        _updateOrderStatus(orderId, OrderLib.OrderStatus.Shipped);
    }

    function confirmDelivery(uint256 orderId)
        external
        orderExists(orderId)
        onlyBuyer(orderId)
        whenNotPaused
    {
        require(_orders[orderId].status == OrderLib.OrderStatus.Shipped, "OrderManagement: Order not shipped");
        _updateOrderStatus(orderId, OrderLib.OrderStatus.Delivered);
    }

    function completeOrder(uint256 orderId)
        external
        orderExists(orderId)
        hasDeposit(orderId)
        nonReentrant
        whenNotPaused
    {
        OrderLib.Order memory order = _orders[orderId];
        require(
            order.status == OrderLib.OrderStatus.Delivered,
            "OrderManagement: Order not delivered"
        );
        require(
            msg.sender == order.buyer ||
            (block.timestamp > order.updatedAt + DISPUTE_TIMEOUT && msg.sender == order.seller),
            "OrderManagement: Not authorized to complete"
        );

        _updateOrderStatus(orderId, OrderLib.OrderStatus.Completed);
        _releasePayment(orderId);
    }

    function cancelOrder(uint256 orderId, string calldata reason)
        external
        orderExists(orderId)
        onlyOrderParticipant(orderId)
        hasDeposit(orderId)
        nonReentrant
        whenNotPaused
    {
        OrderLib.Order memory order = _orders[orderId];
        require(
            order.status == OrderLib.OrderStatus.Created ||
            order.status == OrderLib.OrderStatus.Confirmed ||
            block.timestamp > order.createdAt + ORDER_TIMEOUT,
            "OrderManagement: Cannot cancel order at this stage"
        );

        _updateOrderStatus(orderId, OrderLib.OrderStatus.Cancelled);

        uint256 deposit = _orderDeposits[orderId];
        _orderDeposits[orderId] = 0;

        payable(order.buyer).transfer(deposit);

        emit OrderCancelled(orderId, reason);
        emit PaymentReleased(orderId, order.buyer, deposit);
    }

    function raiseDispute(uint256 orderId)
        external
        orderExists(orderId)
        onlyOrderParticipant(orderId)
        whenNotPaused
    {
        OrderLib.Order memory order = _orders[orderId];
        require(
            order.status == OrderLib.OrderStatus.Confirmed ||
            order.status == OrderLib.OrderStatus.Shipped ||
            order.status == OrderLib.OrderStatus.Delivered,
            "OrderManagement: Cannot dispute at this stage"
        );

        _updateOrderStatus(orderId, OrderLib.OrderStatus.Disputed);
        _disputeDeadlines[orderId] = block.timestamp + DISPUTE_TIMEOUT;

        emit DisputeRaised(orderId, msg.sender);
    }

    function resolveDispute(uint256 orderId, address winner)
        external
        orderExists(orderId)
        onlyOwner
        hasDeposit(orderId)
        nonReentrant
        whenNotPaused
    {
        OrderLib.Order memory order = _orders[orderId];
        require(order.status == OrderLib.OrderStatus.Disputed, "OrderManagement: Order not disputed");
        require(winner == order.buyer || winner == order.seller, "OrderManagement: Invalid winner");

        uint256 deposit = _orderDeposits[orderId];
        _orderDeposits[orderId] = 0;

        if (winner == order.seller) {
            _updateOrderStatus(orderId, OrderLib.OrderStatus.Completed);
            _releasePaymentToSeller(orderId, deposit);
        } else {
            _updateOrderStatus(orderId, OrderLib.OrderStatus.Cancelled);
            payable(order.buyer).transfer(deposit);
            emit PaymentReleased(orderId, order.buyer, deposit);
        }

        emit DisputeResolved(orderId, winner);
    }

    function _releasePayment(uint256 orderId) private {
        uint256 deposit = _orderDeposits[orderId];
        _orderDeposits[orderId] = 0;
        _releasePaymentToSeller(orderId, deposit);
    }

    function _releasePaymentToSeller(uint256 orderId, uint256 deposit) private {
        OrderLib.Order memory order = _orders[orderId];
        uint256 totalPrice = order.amount * order.price;
        uint256 platformFee = _calculatePlatformFee(totalPrice);
        uint256 sellerAmount = totalPrice;

        payable(order.seller).transfer(sellerAmount);
        payable(_feeRecipient).transfer(platformFee);

        emit OrderCompleted(orderId, totalPrice, platformFee);
        emit PaymentReleased(orderId, order.seller, sellerAmount);
    }

    function authorizeSeller(address seller) external onlyOwner {
        require(seller != address(0), "OrderManagement: Invalid seller address");
        require(!_authorizedSellers[seller], "OrderManagement: Seller already authorized");

        _authorizedSellers[seller] = true;
        emit SellerAuthorized(seller);
    }

    function revokeSeller(address seller) external onlyOwner {
        require(_authorizedSellers[seller], "OrderManagement: Seller not authorized");

        _authorizedSellers[seller] = false;
        emit SellerRevoked(seller);
    }

    function updatePlatformFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "OrderManagement: Fee rate too high");

        uint256 oldRate = _platformFeeRate;
        _platformFeeRate = newRate;

        emit PlatformFeeUpdated(oldRate, newRate);
    }

    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "OrderManagement: Invalid recipient");
        _feeRecipient = newRecipient;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getOrderDeposit(uint256 orderId) external view orderExists(orderId) returns (uint256) {
        return _orderDeposits[orderId];
    }

    function getDisputeDeadline(uint256 orderId) external view orderExists(orderId) returns (uint256) {
        return _disputeDeadlines[orderId];
    }
}
