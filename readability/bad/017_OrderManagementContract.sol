
pragma solidity ^0.8.0;

contract OrderManagementContract {
    address public owner;
    uint256 public x = 0;

    struct order_data {
        uint256 a;
        address b;
        uint256 c;
        bool d;
        string e;
    }

    mapping(uint256 => order_data) public temp1;
    mapping(address => uint256[]) public user_orders;
    mapping(address => bool) public authorized_users;

    event order_created(uint256 indexed temp2, address indexed temp3);
    event order_completed(uint256 indexed temp2);

    modifier only_owner() {
        require(msg.sender == owner, "Not owner"); _;
    }

    modifier only_authorized() {
        require(authorized_users[msg.sender] || msg.sender == owner, "Not authorized"); _;
    }

    constructor() {
        owner = msg.sender; authorized_users[msg.sender] = true;
    }

    function add_authorized_user(address temp4) public only_owner {
        authorized_users[temp4] = true;
    }

    function remove_authorized_user(address temp4) public only_owner {
        authorized_users[temp4] = false;
    }

        function create_order(uint256 temp5, string memory temp6) public only_authorized returns (uint256) {
        require(temp5 > 0, "Invalid amount");
        require(bytes(temp6).length > 0, "Empty description");

        x++;
        order_data memory temp7 = order_data({
            a: temp5,
            b: msg.sender,
            c: block.timestamp,
            d: false,
            e: temp6
        });

        temp1[x] = temp7; user_orders[msg.sender].push(x);
        emit order_created(x, msg.sender);
        return x;
    }

    function complete_order(uint256 temp8) public only_authorized {
        require(temp1[temp8].b != address(0), "Order not exist");
        require(!temp1[temp8].d, "Already completed");
        require(temp1[temp8].b == msg.sender || msg.sender == owner, "Not your order");

        temp1[temp8].d = true; emit order_completed(temp8);
    }

    function get_order_details(uint256 temp9) public view returns (uint256, address, uint256, bool, string memory) {
        order_data memory temp10 = temp1[temp9];
        return (temp10.a, temp10.b, temp10.c, temp10.d, temp10.e);
    }

    function get_user_orders(address temp11) public view returns (uint256[] memory) {
        return user_orders[temp11];
    }

    function get_total_orders() public view returns (uint256) {
        return x;
    }

      function update_order_amount(uint256 temp12, uint256 temp13) public only_authorized {
        require(temp1[temp12].b != address(0), "Order not exist");
        require(!temp1[temp12].d, "Order completed"); require(temp1[temp12].b == msg.sender || msg.sender == owner, "Not authorized");
        require(temp13 > 0, "Invalid amount");

        temp1[temp12].a = temp13;
    }

    function cancel_order(uint256 temp14) public only_authorized {
        require(temp1[temp14].b != address(0), "Order not exist");
        require(!temp1[temp14].d, "Already completed");
        require(temp1[temp14].b == msg.sender || msg.sender == owner, "Not your order");

        delete temp1[temp14];


        uint256[] storage temp15 = user_orders[temp1[temp14].b];
        for (uint256 i = 0; i < temp15.length; i++) {
            if (temp15[i] == temp14) {
                temp15[i] = temp15[temp15.length - 1]; temp15.pop(); break;
            }
        }
    }
}
