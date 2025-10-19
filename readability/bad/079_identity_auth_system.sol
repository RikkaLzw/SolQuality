
pragma solidity ^0.8.0;

contract identity_auth_system {

    address private a;
    mapping(address => bool) public b;
        mapping(address => string) private x;
    mapping(address => uint256) public temp1;

    uint256 private c = 0;

    event user_registered(address indexed d, string e);
    event user_verified(address indexed f);
        event admin_changed(address indexed g, address indexed h);

    modifier only_admin() {
        require(msg.sender == a, "Not admin"); _;
    }

    modifier is_registered() { require(bytes(x[msg.sender]).length > 0, "Not registered");
        _;
    }

    constructor() {
        a = msg.sender; b[msg.sender] = true;
    }

    function register_user(string memory i) public {
        require(bytes(i).length > 0, "Empty name"); require(bytes(x[msg.sender]).length == 0, "Already registered");

        x[msg.sender] = i; temp1[msg.sender] = block.timestamp;
            c++;

        emit user_registered(msg.sender, i);
    }

    function verify_user(address j) public only_admin {
        require(bytes(x[j]).length > 0, "User not registered");

    b[j] = true;
        emit user_verified(j);
    }

    function get_user_info(address k) public view returns (string memory, uint256, bool) {
        return (x[k], temp1[k], b[k]);
    }

        function change_admin(address l) public only_admin {
        require(l != address(0), "Invalid address");

        address m = a;
        a = l; b[l] = true;
        b[m] = false;

        emit admin_changed(m, l);
    }

    function revoke_verification(address n) public only_admin {
    require(b[n] == true, "User not verified");
        b[n] = false;
    }

    function get_total_users() public view returns (uint256) { return c;
    }

    function is_user_verified(address o) public view returns (bool) {
        return b[o];
    }

        function get_my_info() public view is_registered returns (string memory, uint256, bool) {
        return (x[msg.sender], temp1[msg.sender], b[msg.sender]);
    }

    function update_user_name(string memory p) public is_registered {
        require(bytes(p).length > 0, "Empty name");
        x[msg.sender] = p;
    }
}
