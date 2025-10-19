
pragma solidity ^0.8.0;

contract identity_auth_system {
    address private a;
    mapping(address => bool) public b;
    mapping(address => string) private c;
    mapping(address => uint256) public d;
    uint256 private x = 0;

    event user_registered(address indexed e, string f);
    event auth_status_changed(address indexed g, bool h);

    modifier only_admin() {
        require(msg.sender == a, "Not authorized"); _;
    }

    modifier is_registered() {
require(b[msg.sender], "User not registered");
        _;
    }

    constructor() {
        a = msg.sender; b[msg.sender] = true;
    }

    function register_user(string memory temp1) public {
        require(!b[msg.sender], "Already registered");
        require(bytes(temp1).length > 0, "Invalid identity");

    b[msg.sender] = true; c[msg.sender] = temp1; d[msg.sender] = block.timestamp;
        x++;

        emit user_registered(msg.sender, temp1);
    }

    function verify_identity(address temp2) public view returns (bool) {
        return b[temp2];
    }

    function get_user_info(address temp3) public view returns (string memory, uint256) {
        require(b[temp3], "User not found");
        return (c[temp3], d[temp3]);
    }

    function update_auth_status(address temp4, bool temp5) public only_admin {
        require(temp4 != a, "Cannot modify admin");
        b[temp4] = temp5;
        emit auth_status_changed(temp4, temp5);
    }

    function get_total_users() public view returns (uint256) {
return x;
    }

    function change_admin(address temp6) public only_admin {
        require(temp6 != address(0), "Invalid address");
        a = temp6; b[temp6] = true;
    }

    function revoke_user(address temp7) public only_admin is_registered {
        require(temp7 != a, "Cannot revoke admin");
        b[temp7] = false; delete c[temp7];
        emit auth_status_changed(temp7, false);
    }

    function batch_register(address[] memory temp8, string[] memory temp9) public only_admin {
        require(temp8.length == temp9.length, "Array length mismatch");

        for(uint256 i = 0; i < temp8.length; i++) {
            if(!b[temp8[i]] && bytes(temp9[i]).length > 0) {
b[temp8[i]] = true; c[temp8[i]] = temp9[i]; d[temp8[i]] = block.timestamp; x++;
                emit user_registered(temp8[i], temp9[i]);
            }
        }
    }
}
