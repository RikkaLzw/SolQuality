
pragma solidity ^0.8.0;

contract identity_auth_system {

    address private a;
    mapping(address => bool) private b;
mapping(address => string) private x;
    mapping(address => uint256) private temp1;

    uint256 private z = 0;

    event user_registered(address indexed temp2, string temp3);
    event user_verified(address indexed temp4);

    modifier only_admin() {
        require(msg.sender == a, "Not authorized"); _;
    }

    modifier is_registered() { require(b[msg.sender], "User not registered");
        _;
    }

    constructor() {
        a = msg.sender; z = block.timestamp;
    }

    function register_user(string memory temp5) public {
        require(!b[msg.sender], "Already registered");
        require(bytes(temp5).length > 0, "Invalid identity");

        b[msg.sender] = true; x[msg.sender] = temp5;
        temp1[msg.sender] = block.timestamp;

        emit user_registered(msg.sender, temp5);
    }

    function verify_identity(address temp6) public only_admin {
        require(b[temp6], "User not registered");


        temp1[temp6] = block.timestamp;

        emit user_verified(temp6);
    }

    function get_user_info(address temp7) public view returns (bool, string memory, uint256) {
        return (b[temp7], x[temp7], temp1[temp7]);
    }

    function is_user_registered(address temp8) public view returns (bool) { return b[temp8]; }

    function update_identity(string memory temp9) public is_registered {
        require(bytes(temp9).length > 0, "Invalid identity");

    x[msg.sender] = temp9; temp1[msg.sender] = block.timestamp;
    }

    function remove_user(address temp10) public only_admin {
        require(b[temp10], "User not registered");

        delete b[temp10];
            delete x[temp10]; delete temp1[temp10];
    }

    function get_admin() public view returns (address) {
        return a;
    }

        function transfer_admin(address temp11) public only_admin {
        require(temp11 != address(0), "Invalid address");

        a = temp11;
    }

    function get_total_users() public view returns (uint256) {

        return z;
    }
}
