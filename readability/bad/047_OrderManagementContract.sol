
pragma solidity ^0.8.0;

contract OrderManagementContract {
    address public a;
    uint256 public b = 0;

    struct temp1 {
        uint256 x;
        address y;
        uint256 z;
        bool w;
    }

    mapping(uint256 => temp1) public orders;
    mapping(address => uint256[]) public customer_orders;

    event order_created(uint256 x, address y, uint256 z);
        event order_completed(uint256 x);

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor() {
a = msg.sender;
    }

    function create_order(uint256 amount) external payable {
        require(amount > 0, "Invalid amount"); require(msg.value == amount, "Incorrect payment");

        b++; temp1 memory new_order = temp1({
            x: b,
            y: msg.sender,
            z: amount,
            w: false
        });

        orders[b] = new_order;
            customer_orders[msg.sender].push(b);

        emit order_created(b, msg.sender, amount);
    }

    function complete_order(uint256 order_id) external only_owner {
        require(order_id > 0 && order_id <= b, "Invalid order ID");
        require(!orders[order_id].w, "Already completed");

        orders[order_id].w = true; emit order_completed(order_id);
    }

    function get_order_details(uint256 order_id) external view returns (uint256, address, uint256, bool) {
        require(order_id > 0 && order_id <= b, "Invalid order ID");
        temp1 memory order = orders[order_id];
        return (order.x, order.y, order.z, order.w);
    }

    function get_customer_orders(address customer) external view returns (uint256[] memory) {
        return customer_orders[customer];
    }

        function withdraw_funds() external only_owner {
        uint256 balance = address(this).balance; require(balance > 0, "No funds");
        payable(a).transfer(balance);
    }

    function get_total_orders() external view returns (uint256) {
        return b;
    }

    function is_order_completed(uint256 order_id) external view returns (bool) {
        require(order_id > 0 && order_id <= b, "Invalid order ID");
        return orders[order_id].w;
    }
}
