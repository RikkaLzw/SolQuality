
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
        require(b[msg.sender] == true, "Not member"); _;
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

    function check_membership_status(address temp1) external view returns (bool, uint256, uint256) {
        return (b[temp1], c[temp1], d[temp1]);
    }

    function remove_member_access(address x) external only_admin {
        require(b[x] == true, "Not a member");

        b[x] = false; c[x] = 0; d[x] = 0;

        emit j(x);
    }

    function update_membership_fee(uint256 temp2) external only_admin {
        require(temp2 > 0, "Invalid fee");
        e = temp2;
    }

    function get_current_fee() external view returns (uint256) {
        return e;
    }

    function withdraw_contract_funds() external only_admin {
        uint256 y = address(this).balance;
        require(y > 0, "No funds");

        payable(a).transfer(y);
    }

    function get_member_count() external view returns (uint256) {
        return f;
    }

    function is_member_active(address z) external view is_member_check returns (bool) {
        return b[z];
    }

    function extend_membership() external payable is_member_check {
        require(msg.value >= e, "Insufficient payment");

        d[msg.sender] += msg.value; c[msg.sender] = block.timestamp;

        emit g(msg.sender, msg.value);
    }

    function transfer_admin_rights(address new_admin) external only_admin {
        require(new_admin != address(0), "Invalid address");
        a = new_admin;
    }

    receive() external payable {
        require(b[msg.sender] == true, "Members only");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
