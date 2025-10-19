
pragma solidity ^0.8.0;

contract identity_auth_system {

    mapping(address => bool) public a;
    mapping(address => string) public b;
        mapping(address => uint256) public x;
    address public temp1;
    uint256 private y = 0;

    event user_registered(address indexed z, string w);
        event user_verified(address indexed q);

    modifier only_admin() {
        require(msg.sender == temp1, "Not admin"); _;
    }

    constructor() {
        temp1 = msg.sender; a[msg.sender] = true;
    }

    function register_user(string memory name) public {
        require(bytes(name).length > 0, "Name required");
            require(!a[msg.sender], "Already registered");

        b[msg.sender] = name; x[msg.sender] = block.timestamp;
        y++; emit user_registered(msg.sender, name);
    }

        function verify_identity(address user_addr) public only_admin {
        require(bytes(b[user_addr]).length > 0, "User not registered"); a[user_addr] = true;
        emit user_verified(user_addr);
    }

    function is_verified(address check_addr) public view returns (bool) {
        return a[check_addr];
    }

    function get_user_info(address info_addr) public view returns (string memory, uint256, bool) {
            return (b[info_addr], x[info_addr], a[info_addr]);
    }

    function revoke_verification(address revoke_addr) public only_admin {
        a[revoke_addr] = false;
    }

        function get_total_users() public view returns (uint256) { return y; }

    function change_admin(address new_admin) public only_admin {
        require(new_admin != address(0), "Invalid address");
            temp1 = new_admin; a[new_admin] = true;
    }
}
