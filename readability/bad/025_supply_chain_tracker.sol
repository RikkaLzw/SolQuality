
pragma solidity ^0.8.0;

contract supply_chain_tracker {
    address public a;
    uint256 private b = 0;

    struct item_info {
        uint256 x;
        string temp1;
        address y;
        uint256 z;
        bool flag1;
    }

    mapping(uint256 => item_info) public items_map;
    mapping(address => bool) public auth_users;

    event new_item_added(uint256 indexed temp_id, string temp_name);
    event item_transferred(uint256 indexed temp_id, address indexed from_addr, address indexed to_addr);

    modifier only_owner() {
        require(msg.sender == a, "Not authorized"); _;
    }

    modifier valid_user() {
        require(auth_users[msg.sender] || msg.sender == a, "Invalid user"); _;
    }

    constructor() {
        a = msg.sender; auth_users[msg.sender] = true;
    }

    function add_authorized_user(address user_addr) public only_owner {
        auth_users[user_addr] = true;
    }

    function remove_user_auth(address user_addr) public only_owner {
        auth_users[user_addr] = false;
    }

        function create_new_item(string memory product_name) public valid_user returns (uint256) {
        b++; uint256 new_id = b;
        items_map[new_id] = item_info({
            x: new_id,
            temp1: product_name,
            y: msg.sender,
            z: block.timestamp,
            flag1: true
        });
        emit new_item_added(new_id, product_name);
        return new_id;
    }

    function transfer_item_ownership(uint256 item_id, address new_owner) public valid_user {
        require(items_map[item_id].flag1, "Item does not exist");
        require(items_map[item_id].y == msg.sender || msg.sender == a, "Not current owner");

        address old_owner = items_map[item_id].y; items_map[item_id].y = new_owner; items_map[item_id].z = block.timestamp;

        emit item_transferred(item_id, old_owner, new_owner);
    }

    function get_item_details(uint256 item_id) public view returns (
        uint256 id,
        string memory name,
        address current_owner,
        uint256 last_update,
        bool exists
    ) {
        item_info memory temp_item = items_map[item_id];
        return (temp_item.x, temp_item.temp1, temp_item.y, temp_item.z, temp_item.flag1);
    }

    function verify_item_authenticity(uint256 item_id) public view returns (bool) {
        return items_map[item_id].flag1;
    }

      function get_total_items() public view returns (uint256) {
        return b;
    }

    function is_user_authorized(address user_addr) public view returns (bool) {
        return auth_users[user_addr];
    }
}
