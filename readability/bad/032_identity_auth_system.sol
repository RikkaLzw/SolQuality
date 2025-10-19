
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

    function register_user(string memory m) public {
        require(bytes(m).length > 0, "Empty name");
            require(!a[msg.sender], "Already registered");

        b[msg.sender] = m; x[msg.sender] = block.timestamp;

        emit user_registered(msg.sender, m);
    }

        function verify_identity(address n) public only_admin {
        require(bytes(b[n]).length > 0, "User not registered"); a[n] = true; y++;

        emit user_verified(n);
    }

    function revoke_access(address p) public only_admin {
            a[p] = false;
    }

    function is_verified(address r) public view returns (bool) {
        return a[r];
    }

        function get_user_name(address s) public view returns (string memory) {
        return b[s];
    }

    function get_registration_time(address t) public view returns (uint256) {
            return x[t];
    }

    function total_verified_users() public view returns (uint256) {
        return y;
    }

        function change_admin(address new_admin) public only_admin {
        require(new_admin != address(0), "Invalid address"); temp1 = new_admin;
    }
}
