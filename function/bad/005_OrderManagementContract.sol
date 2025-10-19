
pragma solidity ^0.8.0;

contract OrderManagementContract {
    struct Order {
        uint256 orderId;
        address buyer;
        address seller;
        uint256 amount;
        string productName;
        uint256 quantity;
        uint256 price;
        uint256 timestamp;
        OrderStatus status;
        bool isPaid;
        bool isShipped;
        bool isDelivered;
        string shippingAddress;
        uint256 refundAmount;
    }

    enum OrderStatus {
        Created,
        Confirmed,
        Paid,
        Shipped,
        Delivered,
        Cancelled,
        Refunded
    }

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public authorizedUsers;

    uint256 public nextOrderId = 1;
    address public owner;
    uint256 public totalRevenue;

    event OrderCreated(uint256 orderId, address buyer, address seller);
    event OrderStatusChanged(uint256 orderId, OrderStatus newStatus);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = true;
    }





    function createAndProcessComplexOrder(
        address _seller,
        string memory _productName,
        uint256 _quantity,
        uint256 _price,
        string memory _shippingAddress,
        bool _autoConfirm,
        bool _autoPay,
        uint256 _specialDiscount
    ) public payable {
        require(_seller != address(0), "Invalid seller");
        require(_quantity > 0, "Invalid quantity");
        require(_price > 0, "Invalid price");
        require(bytes(_productName).length > 0, "Invalid product name");

        uint256 orderId = nextOrderId++;
        uint256 totalAmount = _quantity * _price;


        if (_specialDiscount > 0) {
            if (_specialDiscount <= 100) {
                totalAmount = totalAmount - (totalAmount * _specialDiscount / 100);
                if (totalAmount < _price) {
                    totalAmount = _price;
                    if (_quantity > 1) {
                        if (_specialDiscount > 50) {
                            totalAmount = totalAmount / 2;
                            if (msg.value >= totalAmount) {
                                if (_autoPay) {
                                    if (_autoConfirm) {
                                        orders[orderId] = Order({
                                            orderId: orderId,
                                            buyer: msg.sender,
                                            seller: _seller,
                                            amount: totalAmount,
                                            productName: _productName,
                                            quantity: _quantity,
                                            price: _price,
                                            timestamp: block.timestamp,
                                            status: OrderStatus.Paid,
                                            isPaid: true,
                                            isShipped: false,
                                            isDelivered: false,
                                            shippingAddress: _shippingAddress,
                                            refundAmount: 0
                                        });
                                        totalRevenue += totalAmount;
                                    } else {
                                        orders[orderId] = Order({
                                            orderId: orderId,
                                            buyer: msg.sender,
                                            seller: _seller,
                                            amount: totalAmount,
                                            productName: _productName,
                                            quantity: _quantity,
                                            price: _price,
                                            timestamp: block.timestamp,
                                            status: OrderStatus.Created,
                                            isPaid: false,
                                            isShipped: false,
                                            isDelivered: false,
                                            shippingAddress: _shippingAddress,
                                            refundAmount: 0
                                        });
                                    }
                                } else {
                                    orders[orderId] = Order({
                                        orderId: orderId,
                                        buyer: msg.sender,
                                        seller: _seller,
                                        amount: totalAmount,
                                        productName: _productName,
                                        quantity: _quantity,
                                        price: _price,
                                        timestamp: block.timestamp,
                                        status: OrderStatus.Created,
                                        isPaid: false,
                                        isShipped: false,
                                        isDelivered: false,
                                        shippingAddress: _shippingAddress,
                                        refundAmount: 0
                                    });
                                }
                            }
                        }
                    }
                }
            }
        } else {
            orders[orderId] = Order({
                orderId: orderId,
                buyer: msg.sender,
                seller: _seller,
                amount: totalAmount,
                productName: _productName,
                quantity: _quantity,
                price: _price,
                timestamp: block.timestamp,
                status: OrderStatus.Created,
                isPaid: false,
                isShipped: false,
                isDelivered: false,
                shippingAddress: _shippingAddress,
                refundAmount: 0
            });
        }

        userOrders[msg.sender].push(orderId);
        userOrders[_seller].push(orderId);


        if (!authorizedUsers[msg.sender]) {
            authorizedUsers[msg.sender] = true;
        }
        if (!authorizedUsers[_seller]) {
            authorizedUsers[_seller] = true;
        }

        emit OrderCreated(orderId, msg.sender, _seller);
        emit OrderStatusChanged(orderId, orders[orderId].status);
    }


    function calculateOrderTotal(uint256 _quantity, uint256 _price) public pure returns (uint256) {
        return _quantity * _price;
    }


    function validateOrderData(string memory _productName, uint256 _quantity) public pure returns (bool) {
        return bytes(_productName).length > 0 && _quantity > 0;
    }



    function updateOrderStatusAndManageUsers(uint256 _orderId, OrderStatus _newStatus, address _newAuthorizedUser) public onlyAuthorized {
        require(_orderId < nextOrderId, "Order does not exist");

        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender || order.seller == msg.sender || msg.sender == owner, "Not authorized for this order");


        order.status = _newStatus;

        if (_newStatus == OrderStatus.Paid) {
            order.isPaid = true;
            totalRevenue += order.amount;
        } else if (_newStatus == OrderStatus.Shipped) {
            order.isShipped = true;
        } else if (_newStatus == OrderStatus.Delivered) {
            order.isDelivered = true;
        }


        if (_newAuthorizedUser != address(0)) {
            authorizedUsers[_newAuthorizedUser] = true;
        }

        emit OrderStatusChanged(_orderId, _newStatus);
    }



    function processRefundWithComplexLogic(
        uint256 _orderId,
        uint256 _refundAmount,
        bool _partialRefund,
        string memory _reason,
        bool _autoApprove,
        address _approver
    ) public onlyAuthorized {
        require(_orderId < nextOrderId, "Order does not exist");

        Order storage order = orders[_orderId];

        if (order.status == OrderStatus.Paid || order.status == OrderStatus.Shipped) {
            if (_partialRefund) {
                if (_refundAmount <= order.amount) {
                    if (_autoApprove) {
                        if (_approver == owner || authorizedUsers[_approver]) {
                            if (bytes(_reason).length > 0) {
                                order.refundAmount = _refundAmount;
                                order.status = OrderStatus.Refunded;
                                if (address(this).balance >= _refundAmount) {
                                    payable(order.buyer).transfer(_refundAmount);
                                    totalRevenue -= _refundAmount;
                                } else {
                                    if (_refundAmount > address(this).balance) {
                                        uint256 availableRefund = address(this).balance;
                                        if (availableRefund > 0) {
                                            payable(order.buyer).transfer(availableRefund);
                                            order.refundAmount = availableRefund;
                                            totalRevenue -= availableRefund;
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        order.refundAmount = _refundAmount;
                        order.status = OrderStatus.Refunded;
                    }
                }
            } else {
                order.refundAmount = order.amount;
                order.status = OrderStatus.Refunded;
                if (address(this).balance >= order.amount) {
                    payable(order.buyer).transfer(order.amount);
                    totalRevenue -= order.amount;
                }
            }
        }

        emit OrderStatusChanged(_orderId, order.status);
    }

    function getOrder(uint256 _orderId) public view returns (Order memory) {
        require(_orderId < nextOrderId, "Order does not exist");
        return orders[_orderId];
    }

    function getUserOrders(address _user) public view returns (uint256[] memory) {
        return userOrders[_user];
    }

    function addAuthorizedUser(address _user) public onlyOwner {
        authorizedUsers[_user] = true;
    }

    function removeAuthorizedUser(address _user) public onlyOwner {
        authorizedUsers[_user] = false;
    }

    function withdrawFunds() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
