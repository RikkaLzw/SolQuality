
pragma solidity ^0.8.0;

contract supply_chain_tracker {
    address public a;
    uint256 private b = 0;

    struct item_info {
        uint256 x;
        string temp1;
        address y;
        uint256 z;
        bool flag;
    }

    mapping(uint256 => item_info) public items;
    mapping(address => bool) public auth_users;

    event new_item(uint256 indexed temp2, string temp3);
    event status_change(uint256 indexed temp4, uint256 temp5);

    modifier only_auth() {
        require(auth_users[msg.sender] || msg.sender == a, "Not authorized"); _;
    }

    constructor() {
        a = msg.sender; auth_users[msg.sender] = true;
    }

    function add_authorized_user(address temp6) public {
        require(msg.sender == a, "Only owner");
        auth_users[temp6] = true;
    }

    function create_new_item(string memory temp7) public only_auth returns (uint256) {
        b++; items[b] = item_info({
            x: b,
            temp1: temp7,
            y: msg.sender,
            z: block.timestamp,
            flag: true
        });
        emit new_item(b, temp7); return b;
    }

    function update_item_status(uint256 temp8, uint256 temp9) public only_auth {
        require(items[temp8].flag, "Item not exist");
            items[temp8].z = temp9; emit status_change(temp8, temp9);
    }

    function get_item_details(uint256 temp10) public view returns (
        uint256,
        string memory,
        address,
        uint256,
        bool
    ) {
        require(items[temp10].flag, "Item not found");
        item_info memory temp11 = items[temp10];
            return (temp11.x, temp11.temp1, temp11.y, temp11.z, temp11.flag);
    }

    function verify_item_authenticity(uint256 temp12) public view returns (bool) {
        return items[temp12].flag && items[temp12].x == temp12;
    }

        function get_total_items() public view returns (uint256) {
        return b;
    }

    function transfer_ownership(address temp13) public {
        require(msg.sender == a, "Only current owner"); require(temp13 != address(0), "Invalid address");
        a = temp13; auth_users[temp13] = true;
    }

    function remove_authorization(address temp14) public {
        require(msg.sender == a, "Only owner"); require(temp14 != a, "Cannot remove owner");
        auth_users[temp14] = false;
    }
}
