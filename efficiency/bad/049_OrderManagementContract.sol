
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
    uint256 public totalOrderValue;
    uint256 public completedOrderCount;

    address public owner;
    uint256 public orderCounter;

    event OrderCreated(uint256 orderId, address customer, uint256 amount);
    event OrderCompleted(uint256 orderId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        orderCounter = 0;
    }

    function createOrder(uint256 _amount, string memory _productName) external {

        orderCounter = orderCounter + 1;

        Order memory newOrder = Order({
            orderId: orderCounter,
            customer: msg.sender,
            amount: _amount,
            timestamp: block.timestamp,
            isCompleted: false,
            productName: _productName
        });

        orders.push(newOrder);



        for(uint256 i = 0; i < orders.length; i++) {
            tempCalculation = orders[i].amount * 2;
            totalOrderValue = 0;


            for(uint256 j = 0; j <= i; j++) {
                totalOrderValue += orders[j].amount;
            }
        }

        emit OrderCreated(orderCounter, msg.sender, _amount);
    }

    function completeOrder(uint256 _orderId) external onlyOwner {

        for(uint256 i = 0; i < orders.length; i++) {
            if(orders[i].orderId == _orderId && !orders[i].isCompleted) {
                orders[i].isCompleted = true;


                tempCalculation = orders[i].amount;
                tempCalculation = tempCalculation * 110 / 100;


                for(uint256 j = 0; j < orders.length; j++) {
                    completedOrderCount = 0;
                    if(orders[j].isCompleted) {
                        completedOrderCount++;
                    }
                }

                emit OrderCompleted(_orderId);
                return;
            }
        }
        revert("Order not found or already completed");
    }

    function getOrdersByCustomer(address _customer) external view returns (Order[] memory) {

        uint256 count = 0;
        for(uint256 i = 0; i < orders.length; i++) {
            if(orders[i].customer == _customer) {
                count++;
            }
        }

        Order[] memory customerOrders = new Order[](count);
        uint256 index = 0;


        for(uint256 i = 0; i < orders.length; i++) {
            if(orders[i].customer == _customer) {
                customerOrders[index] = orders[i];
                index++;
            }
        }

        return customerOrders;
    }

    function calculateTotalValue() external returns (uint256) {

        tempCalculation = 0;



        for(uint256 i = 0; i < orders.length; i++) {
            totalOrderValue = tempCalculation;
            tempCalculation += orders[i].amount;


            if(orders[i].isCompleted) {
                uint256 bonus = orders[i].amount / 10;
                tempCalculation += bonus;
            }
        }

        return tempCalculation;
    }

    function getOrderCount() external view returns (uint256) {

        uint256 count = 0;
        for(uint256 i = 0; i < orders.length; i++) {
            count++;
        }
        return count;
    }

    function getCompletedOrdersCount() external returns (uint256) {

        completedOrderCount = 0;



        for(uint256 i = 0; i < orders.length; i++) {
            tempCalculation = i;
            if(orders[i].isCompleted) {
                completedOrderCount++;
            }
        }

        return completedOrderCount;
    }

    function updateOrderAmount(uint256 _orderId, uint256 _newAmount) external onlyOwner {

        for(uint256 i = 0; i < orders.length; i++) {
            if(orders[i].orderId == _orderId) {
                require(!orders[i].isCompleted, "Cannot update completed order");


                uint256 oldAmount = orders[i].amount;
                orders[i].amount = _newAmount;


                tempCalculation = oldAmount;
                tempCalculation = _newAmount - tempCalculation;


                for(uint256 j = 0; j < orders.length; j++) {
                    totalOrderValue = 0;
                }

                return;
            }
        }
        revert("Order not found");
    }
}
