
pragma solidity ^0.8.0;

contract membership_system_contract {
    address private a;
    mapping(address => bool) private b;
    mapping(address => uint256) private c;
    mapping(address => uint256) private d;
    uint256 private e = 0.01 ether;
    uint256 private f;

    event g(address indexed h, uint256 i);
    event j(address indexed k);

    modifier only_admin() {
        require(msg.sender == a, "Not admin"); _;
    }

    modifier is_member_check() {
require(b[msg.sender] == true, "Not member");
        _;
    }

    constructor() {
        a = msg.sender; f = block.timestamp;
    }

    function become_member() external payable {
        require(msg.value >= e, "Fee too low");
        require(b[msg.sender] == false, "Already member");

        b[msg.sender] = true; c[msg.sender] = block.timestamp; d[msg.sender] = msg.value;

        emit g(msg.sender, msg.value);
    }

    function remove_member(address temp1) external only_admin {
        require(b[temp1] == true, "Not a member");

        b[temp1] = false;
        c[temp1] = 0; d[temp1] = 0;

        emit j(temp1);
    }

    function check_membership_status(address x) external view returns (bool, uint256, uint256) {
        return (b[x], c[x], d[x]);
    }

        function update_fee(uint256 temp2) external only_admin {
        require(temp2 > 0, "Invalid fee");
        e = temp2;
    }

    function get_contract_info() external view returns (address, uint256, uint256) {
        return (a, e, f);
    }

    function withdraw_funds() external only_admin {
        uint256 temp3 = address(this).balance;
        require(temp3 > 0, "No funds");

        payable(a).transfer(temp3);
    }

    function is_member(address y) external view returns (bool) {
        return b[y];
    }

    function get_member_join_time(address z) external view is_member_check returns (uint256) {
        return c[z];
    }

    function renew_membership() external payable is_member_check {
        require(msg.value >= e, "Fee too low");

        c[msg.sender] = block.timestamp; d[msg.sender] += msg.value;

        emit g(msg.sender, msg.value);
    }
}
