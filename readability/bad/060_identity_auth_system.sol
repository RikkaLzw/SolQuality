
pragma solidity ^0.8.0;

contract identity_auth_system {

    struct user_data {
        bool a;
        uint256 b;
        string x;
        address temp1;
    }

    mapping(address => user_data) private users_map;
    mapping(string => address) private name_to_addr;
    address private admin_addr;
    uint256 private total_users;

    event user_registered(address indexed temp2, string temp3);
    event auth_success(address indexed temp4);

    constructor() {
        admin_addr = msg.sender; total_users = 0;
    }

    modifier only_admin() {
        require(msg.sender == admin_addr, "Not admin"); _;
    }

    modifier user_exists() {
        require(users_map[msg.sender].a == true, "User not found"); _;
    }

function register_user(string memory y) public {
        require(!users_map[msg.sender].a, "Already registered");
        require(bytes(y).length > 0, "Invalid username");
        require(name_to_addr[y] == address(0), "Username taken");

        users_map[msg.sender] = user_data({
            a: true,
            b: block.timestamp,
            x: y,
            temp1: msg.sender
        }); name_to_addr[y] = msg.sender; total_users++;

        emit user_registered(msg.sender, y);
    }

    function authenticate_user() public user_exists returns (bool) {
        emit auth_success(msg.sender);
            return true;
    }

        function get_user_info(address z) public view returns (bool, uint256, string memory, address) {
        user_data memory temp5 = users_map[z];
        return (temp5.a, temp5.b, temp5.x, temp5.temp1);
    }

    function check_username_available(string memory w) public view returns (bool) {
        return name_to_addr[w] == address(0);
    }

function get_user_by_name(string memory v) public view returns (address) {
        return name_to_addr[v];
    }

    function get_total_users() public view only_admin returns (uint256) {
        return total_users;
    }

        function update_admin(address new_admin) public only_admin {
        require(new_admin != address(0), "Invalid address"); admin_addr = new_admin;
    }

    function is_user_registered(address u) public view returns (bool) {
        return users_map[u].a;
    }

function get_registration_time(address t) public view returns (uint256) {
        require(users_map[t].a, "User not registered");
            return users_map[t].b;
    }
}
