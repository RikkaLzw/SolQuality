
pragma solidity ^0.8.0;

contract OrderManagementContract {
    enum OrderStatus { Pending, Confirmed, Shipped, Delivered, Cancelled }

    struct Order {
        uint256 orderId;
        address buyer;
        address seller;
        uint256 amount;
        uint256 quantity;
        string productName;
        OrderStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        bool isPaid;
        string shippingAddress;
        uint256 discount;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public authorizedSellers;

    uint256 public nextOrderId = 1;
    uint256 public totalOrders;
    address public owner;

    event OrderCreated(uint256 indexed orderId, address indexed buyer, address indexed seller);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus status);
    event PaymentProcessed(uint256 indexed orderId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }





    function createOrderAndProcessPaymentAndUpdateInventoryAndNotifyUsers(
        address _seller,
        uint256 _amount,
        uint256 _quantity,
        string memory _productName,
        string memory _shippingAddress,
        uint256 _discount,
        bool _autoConfirm,
        uint256 _priority
    ) public payable {

        if (_seller != address(0)) {
            if (_amount > 0) {
                if (_quantity > 0) {
                    if (bytes(_productName).length > 0) {
                        if (bytes(_shippingAddress).length > 0) {
                            if (msg.value >= _amount) {
                                if (authorizedSellers[_seller] || _seller == owner) {
                                    uint256 orderId = nextOrderId++;

                                    Order storage newOrder = orders[orderId];
                                    newOrder.orderId = orderId;
                                    newOrder.buyer = msg.sender;
                                    newOrder.seller = _seller;
                                    newOrder.amount = _amount;
                                    newOrder.quantity = _quantity;
                                    newOrder.productName = _productName;
                                    newOrder.status = OrderStatus.Pending;
                                    newOrder.createdAt = block.timestamp;
                                    newOrder.updatedAt = block.timestamp;
                                    newOrder.isPaid = true;
                                    newOrder.shippingAddress = _shippingAddress;
                                    newOrder.discount = _discount;

                                    userOrders[msg.sender].push(orderId);
                                    totalOrders++;


                                    if (msg.value > _amount) {
                                        payable(msg.sender).transfer(msg.value - _amount);
                                    }


                                    if (_autoConfirm) {
                                        if (_priority > 5) {
                                            newOrder.status = OrderStatus.Confirmed;
                                            newOrder.updatedAt = block.timestamp;
                                        }
                                    }


                                    if (_quantity < 100) {

                                        if (newOrder.status == OrderStatus.Confirmed) {

                                        }
                                    }

                                    emit OrderCreated(orderId, msg.sender, _seller);
                                    emit PaymentProcessed(orderId, _amount);

                                    if (newOrder.status == OrderStatus.Confirmed) {
                                        emit OrderStatusUpdated(orderId, OrderStatus.Confirmed);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function calculateOrderTotal(uint256 _orderId) public view returns (uint256) {
        Order memory order = orders[_orderId];
        return order.amount - order.discount;
    }


    function validateOrderData(uint256 _orderId) public view returns (bool) {
        Order memory order = orders[_orderId];
        return order.buyer != address(0) && order.seller != address(0) && order.amount > 0;
    }



    function updateOrderStatusAndProcessRefundAndNotifyParties(uint256 _orderId, OrderStatus _status, bool _shouldRefund) public {
        require(_orderId < nextOrderId && _orderId > 0, "Invalid order ID");
        Order storage order = orders[_orderId];
        require(msg.sender == order.seller || msg.sender == owner, "Unauthorized");


        order.status = _status;
        order.updatedAt = block.timestamp;


        if (_shouldRefund && order.isPaid) {
            if (_status == OrderStatus.Cancelled) {
                payable(order.buyer).transfer(order.amount);
                order.isPaid = false;
            }
        }


        emit OrderStatusUpdated(_orderId, _status);
    }

    function getOrder(uint256 _orderId) public view returns (Order memory) {
        return orders[_orderId];
    }

    function getUserOrders(address _user) public view returns (uint256[] memory) {
        return userOrders[_user];
    }

    function authorizeSeller(address _seller) public onlyOwner {
        authorizedSellers[_seller] = true;
    }

    function revokeSeller(address _seller) public onlyOwner {
        authorizedSellers[_seller] = false;
    }



    function batchUpdateOrders(
        uint256[] memory _orderIds,
        OrderStatus[] memory _statuses,
        bool[] memory _shouldRefund,
        uint256[] memory _newAmounts,
        string[] memory _notes,
        bool _forceUpdate
    ) public onlyOwner {
        require(_orderIds.length == _statuses.length, "Array length mismatch");

        for (uint i = 0; i < _orderIds.length; i++) {
            if (_orderIds[i] < nextOrderId && _orderIds[i] > 0) {
                Order storage order = orders[_orderIds[i]];

                if (order.buyer != address(0)) {
                    if (_forceUpdate || order.status != OrderStatus.Delivered) {
                        if (_statuses[i] == OrderStatus.Cancelled) {
                            if (_shouldRefund[i] && order.isPaid) {
                                if (address(this).balance >= order.amount) {
                                    payable(order.buyer).transfer(order.amount);
                                    order.isPaid = false;
                                }
                            }
                        }

                        order.status = _statuses[i];
                        order.updatedAt = block.timestamp;

                        if (i < _newAmounts.length && _newAmounts[i] > 0) {
                            order.amount = _newAmounts[i];
                        }

                        emit OrderStatusUpdated(_orderIds[i], _statuses[i]);
                    }
                }
            }
        }
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
