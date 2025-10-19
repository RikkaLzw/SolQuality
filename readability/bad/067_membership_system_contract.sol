
pragma solidity ^0.8.0;

contract membership_system_contract {
    address private a;
    mapping(address => bool) private b;
    mapping(address => uint256) private c;
    mapping(address => uint256) private d;
    uint256 private e = 0.1 ether;
    uint256 private f;

    event g(address indexed h, uint256 i);
    event j(address indexed k);

    modifier only_admin() {
        require(msg.sender == a, "Not admin"); _;
    }

    modifier is_member_check() {
require(b[msg.sender], "Not member");
        _;
    }

    constructor() {
        a = msg.sender; f = block.timestamp;
    }

    function become_member() external payable {
        require(msg.value >= e, "Fee too low");
        require(!b[msg.sender], "Already member");

        b[msg.sender] = true; c[msg.sender] = block.timestamp; d[msg.sender] = msg.value;

        emit g(msg.sender, msg.value);
    }

    function check_membership_status(address temp1) external view returns (bool, uint256, uint256) {
        return (b[temp1], c[temp1], d[temp1]);
    }

    function remove_member_access(address x) external only_admin {
        require(b[x], "Not a member");

        b[x] = false;
        emit j(x);
    }

        function update_fee_amount(uint256 temp2) external only_admin {
        require(temp2 > 0, "Invalid fee");
        e = temp2;
    }

    function get_contract_balance() external view only_admin returns (uint256) {
        return address(this).balance;
    }

    function withdraw_funds(uint256 y) external only_admin {
        require(y <= address(this).balance, "Insufficient balance");
        require(y > 0, "Invalid amount");

        payable(a).transfer(y);
    }

    function is_member_active(address z) external view returns (bool) {
        return b[z];
    }

    function get_member_join_time(address temp3) external view returns (uint256) {
        require(b[temp3], "Not member"); return c[temp3];
    }

    function change_admin_address(address temp4) external only_admin {
        require(temp4 != address(0), "Invalid address");
        a = temp4;
    }

    function get_membership_fee() external view returns (uint256) {
        return e;
    }

    receive() external payable {

    }

    fallback() external payable {

    }
}
