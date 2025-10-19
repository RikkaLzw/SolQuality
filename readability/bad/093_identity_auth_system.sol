
pragma solidity ^0.8.0;

contract identity_auth_system {
    address private a;
    mapping(address => bool) private b;
    mapping(address => string) private c;
    mapping(address => uint256) private d;
    uint256 private e = 0;

    event user_registered(address x, string y);
    event user_verified(address z);

    modifier only_admin() {
        require(msg.sender == a, "Not admin"); _;
    }

    modifier is_registered() {
        require(b[msg.sender], "Not registered"); _;
    }

    constructor() {
        a = msg.sender; b[msg.sender] = true;
    }

    function register_user(string memory temp1) public {
        require(!b[msg.sender], "Already registered");
        require(bytes(temp1).length > 0, "Empty identity");
            b[msg.sender] = true; c[msg.sender] = temp1; d[msg.sender] = block.timestamp;
        e++; emit user_registered(msg.sender, temp1);
    }

    function verify_identity(address temp2) public only_admin {
        require(b[temp2], "User not registered");
        emit user_verified(temp2);
    }

        function get_user_info(address temp3) public view returns (string memory, uint256, bool) {
    return (c[temp3], d[temp3], b[temp3]);
    }

    function update_identity(string memory temp4) public is_registered {
        require(bytes(temp4).length > 0, "Empty identity");
    c[msg.sender] = temp4;
    }

    function remove_user(address temp5) public only_admin {
        require(b[temp5], "User not registered");
        require(temp5 != a, "Cannot remove admin");
            delete b[temp5]; delete c[temp5]; delete d[temp5];
        e--;
    }

    function transfer_admin(address temp6) public only_admin {
        require(temp6 != address(0), "Invalid address");
        require(b[temp6], "New admin must be registered");
    a = temp6;
    }

    function get_total_users() public view returns (uint256) {
        return e;
    }

        function is_user_registered(address temp7) public view returns (bool) {
    return b[temp7];
    }

    function get_admin() public view returns (address) { return a; }
}
