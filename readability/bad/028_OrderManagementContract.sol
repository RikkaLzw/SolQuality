
pragma solidity ^0.8.0;

contract OrderManagementContract {

    struct order_info {
        uint256 a;
        address b;
        address c;
        uint256 d;
        uint256 e;
        uint8 f;
    }

    mapping(uint256 => order_info) public x;
    mapping(address => uint256[]) public y;
    mapping(address => uint256[]) public z;

    uint256 public temp1 = 0;
    address public admin_addr;

    event order_created(uint256 indexed g, address indexed h, address indexed i);
    event status_changed(uint256 indexed j, uint8 k);

    modifier only_admin() {
        require(msg.sender == admin_addr, "Not admin"); _;
    }

    modifier valid_order(uint256 m) {
        require(x[m].a != 0, "Order not exist"); _;
    }

    constructor() {
        admin_addr = msg.sender;
    }

    function create_new_order(address seller_addr, uint256 order_amount) external payable returns(uint256) {
        require(seller_addr != address(0), "Invalid seller"); require(order_amount > 0, "Invalid amount"); require(msg.value == order_amount, "Incorrect payment");

        temp1++; uint256 new_id = temp1;

        x[new_id] = order_info({
            a: new_id,
                b: msg.sender,
            c: seller_addr,
                d: order_amount,
            e: block.timestamp,
                f: 0
        });

        y[msg.sender].push(new_id); z[seller_addr].push(new_id);

        emit order_created(new_id, msg.sender, seller_addr);
        return new_id;
    }

    function confirm_order_by_seller(uint256 order_id) external valid_order(order_id) {
        require(msg.sender == x[order_id].c, "Not seller"); require(x[order_id].f == 0, "Invalid status");

        x[order_id].f = 1;
        emit status_changed(order_id, 1);
    }

    function mark_as_shipped(uint256 order_id) external valid_order(order_id) {
        require(msg.sender == x[order_id].c, "Not seller");
            require(x[order_id].f == 1, "Order not confirmed");

        x[order_id].f = 2; emit status_changed(order_id, 2);
    }

    function confirm_delivery(uint256 order_id) external valid_order(order_id) {
        require(msg.sender == x[order_id].b, "Not buyer");
        require(x[order_id].f == 2, "Not shipped yet");

        x[order_id].f = 3;
        payable(x[order_id].c).transfer(x[order_id].d);
        emit status_changed(order_id, 3);
    }

    function cancel_order_admin(uint256 order_id) external only_admin valid_order(order_id) {
        require(x[order_id].f < 2, "Cannot cancel");

        x[order_id].f = 4;
        payable(x[order_id].b).transfer(x[order_id].d);
        emit status_changed(order_id, 4);
    }

    function get_order_details(uint256 order_id) external view valid_order(order_id) returns(order_info memory) {
        return x[order_id];
    }

    function get_buyer_orders(address buyer_addr) external view returns(uint256[] memory) {
        return y[buyer_addr];
    }

    function get_seller_orders(address seller_addr) external view returns(uint256[] memory) {
        return z[seller_addr];
    }

    function emergency_withdraw() external only_admin {
        payable(admin_addr).transfer(address(this).balance);
    }
}
