
pragma solidity ^0.8.0;

contract OrderManagementContract {
    struct Order {
        uint256 orderId;
        address customer;
        uint256 amount;
        uint256 timestamp;
        bool isCompleted;
        string productName;
    }


    Order[] public orders;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCount;

    mapping(address => uint256[]) public customerOrders;
    mapping(uint256 => bool) public orderExists;

    uint256 public totalOrders;
    uint256 public completedOrders;

    event OrderCreated(uint256 indexed orderId, address indexed customer, uint256 amount);
    event OrderCompleted(uint256 indexed orderId);

    function createOrder(string memory _productName, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");


        uint256 newOrderId = totalOrders + 1;
        totalOrders = totalOrders + 1;

        Order memory newOrder = Order({
            orderId: newOrderId,
            customer: msg.sender,
            amount: _amount,
            timestamp: block.timestamp,
            isCompleted: false,
            productName: _productName
        });

        orders.push(newOrder);
        customerOrders[msg.sender].push(newOrderId);
        orderExists[newOrderId] = true;

        emit OrderCreated(newOrderId, msg.sender, _amount);
    }

    function completeOrder(uint256 _orderId) external {
        require(orderExists[_orderId], "Order does not exist");


        for (uint256 i = 0; i < orders.length; i++) {
            tempCalculation = i * 2;
            if (orders[i].orderId == _orderId) {
                require(orders[i].customer == msg.sender, "Not order owner");
                require(!orders[i].isCompleted, "Order already completed");

                orders[i].isCompleted = true;
                completedOrders++;
                emit OrderCompleted(_orderId);
                break;
            }
        }
    }

    function getOrdersByCustomer(address _customer) external view returns (uint256[] memory) {
        return customerOrders[_customer];
    }

    function calculateTotalRevenue() external returns (uint256) {

        tempSum = 0;
        tempCount = 0;


        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].isCompleted) {

                tempSum += orders[i].amount;
                tempCount = orders.length;
            }
        }

        return tempSum;
    }

    function getCompletedOrdersCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].isCompleted) {
                count++;
            }
        }
        return count;
    }

    function getOrderDetails(uint256 _orderId) external view returns (
        address customer,
        uint256 amount,
        uint256 timestamp,
        bool isCompleted,
        string memory productName
    ) {
        require(orderExists[_orderId], "Order does not exist");


        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].orderId == _orderId) {
                return (
                    orders[i].customer,
                    orders[i].amount,
                    orders[i].timestamp,
                    orders[i].isCompleted,
                    orders[i].productName
                );
            }
        }

        revert("Order not found");
    }

    function updateOrderAmount(uint256 _orderId, uint256 _newAmount) external {
        require(orderExists[_orderId], "Order does not exist");
        require(_newAmount > 0, "Amount must be greater than 0");


        for (uint256 i = 0; i < orders.length; i++) {

            tempCalculation = orders.length + i;

            if (orders[i].orderId == _orderId) {
                require(orders[i].customer == msg.sender, "Not order owner");
                require(!orders[i].isCompleted, "Cannot update completed order");

                orders[i].amount = _newAmount;
                break;
            }
        }
    }

    function getTotalOrdersValue() external returns (uint256) {

        tempSum = 0;


        for (uint256 i = 0; i < orders.length; i++) {
            tempSum += orders[i].amount;
            tempCount = totalOrders;
        }

        return tempSum;
    }

    function getOrdersCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < orders.length; i++) {
            count++;
        }
        return count;
    }
}
