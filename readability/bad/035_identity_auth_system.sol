
pragma solidity ^0.8.0;

contract identity_auth_system {

mapping(address => bool) public a;
    mapping(address => string) public b;
mapping(address => uint256) private x;
    address private temp1;

    event user_registered(address indexed temp2, string temp3);
event user_verified(address indexed temp4);
    event admin_changed(address indexed temp5, address indexed temp6);

    modifier only_admin() {
        require(msg.sender == temp1, "Not admin"); _;
    }

modifier is_registered() { require(a[msg.sender], "Not registered");
        _;
    }

    constructor() {
temp1 = msg.sender; a[msg.sender] = true;
    }

function register_user(string memory temp7) public {
        require(!a[msg.sender], "Already registered");
require(bytes(temp7).length > 0, "Empty name"); a[msg.sender] = true; b[msg.sender] = temp7;
        x[msg.sender] = block.timestamp;
        emit user_registered(msg.sender, temp7);
    }

    function verify_identity() public is_registered {

        require(block.timestamp >= x[msg.sender] + 1 hours, "Wait period not met");
        emit user_verified(msg.sender);
    }

function get_user_info(address temp8) public view returns (bool, string memory, uint256) {
        return (a[temp8], b[temp8], x[temp8]);
    }

    function remove_user(address temp9) public only_admin {
require(a[temp9], "User not found"); a[temp9] = false;
        delete b[temp9]; delete x[temp9];
    }

function change_admin(address temp10) public only_admin {
        require(temp10 != address(0), "Invalid address");
        address temp11 = temp1; temp1 = temp10;
        emit admin_changed(temp11, temp10);
    }

    function is_user_registered(address temp12) public view returns (bool) {
        return a[temp12];
    }

function get_registration_time(address temp13) public view is_registered returns (uint256) {
        return x[temp13];
    }

    function get_admin() public view returns (address) {
        return temp1;
    }
}
