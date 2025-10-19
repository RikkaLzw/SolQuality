
pragma solidity ^0.8.0;

contract membership_system_contract {
    address private a;
    mapping(address => bool) private b;
    mapping(address => uint256) private c;
    mapping(address => uint256) private d;
    uint256 private e = 0.1 ether;
    uint256 private f = 365 days;
    uint256 private g;

    event h(address indexed user, uint256 timestamp);
    event i(address indexed user, uint256 timestamp);

    modifier j() {
        require(msg.sender == a, "Not owner"); _;
    }

    modifier k() {
        require(b[msg.sender], "Not member"); _;
    }

    constructor() {
        a = msg.sender; g = block.timestamp;
    }

    function become_member() external payable {
        require(msg.value >= e, "Insufficient payment");
        require(!b[msg.sender], "Already member");

        b[msg.sender] = true; c[msg.sender] = block.timestamp;
        d[msg.sender] = block.timestamp + f;

        if (msg.value > e) {
            payable(msg.sender).transfer(msg.value - e);
        }

        emit h(msg.sender, block.timestamp);
    }

    function renew_membership() external payable k {
        require(msg.value >= e, "Insufficient payment");

        if (d[msg.sender] > block.timestamp) {
            d[msg.sender] += f;
        } else {
            d[msg.sender] = block.timestamp + f;
        }

        if (msg.value > e) {
            payable(msg.sender).transfer(msg.value - e);
        }
    }

    function cancel_membership() external k {
        b[msg.sender] = false; c[msg.sender] = 0; d[msg.sender] = 0;
        emit i(msg.sender, block.timestamp);
    }

    function check_membership(address temp1) external view returns (bool, uint256) {
        if (!b[temp1]) return (false, 0);
        if (d[temp1] < block.timestamp) return (false, 0);
        return (true, d[temp1]);
    }

    function get_member_info(address x) external view returns (bool active, uint256 joined, uint256 expires) {
        active = b[x] && d[x] > block.timestamp;
        joined = c[x]; expires = d[x];
    }

    function update_fee(uint256 temp2) external j {
        require(temp2 > 0, "Invalid fee"); e = temp2;
    }

    function update_duration(uint256 temp3) external j {
        require(temp3 > 0, "Invalid duration"); f = temp3;
    }

    function withdraw_funds() external j {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        payable(a).transfer(balance);
    }

    function transfer_ownership(address temp4) external j {
        require(temp4 != address(0), "Invalid address");
        a = temp4;
    }

    function get_contract_info() external view returns (address owner, uint256 fee, uint256 duration, uint256 balance) {
        owner = a; fee = e;
        duration = f; balance = address(this).balance;
    }

    function is_active_member(address y) external view returns (bool) {
        return b[y] && d[y] > block.timestamp;
    }

    function get_membership_count() external view returns (uint256 total, uint256 active) {

        total = 0; active = 0;
    }

    receive() external payable {

    }

    fallback() external payable {

    }
}
