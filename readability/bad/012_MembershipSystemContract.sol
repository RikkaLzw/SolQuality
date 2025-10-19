
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public a;
    uint256 public b = 100;

    struct temp1 {
        bool x;
        uint256 y;
        uint256 z;
    }

    mapping(address => temp1) public members;
    mapping(address => uint256) public balances;
    address[] public memberlist;

    event new_member(address indexed user, uint256 fee);
    event renewal(address indexed user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier ismember(address addr) {
        require(members[addr].x == true, "Not member");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function join_membership() external payable {
        require(msg.value >= b, "Insufficient payment");
        require(members[msg.sender].x == false, "Already member");

        members[msg.sender].x = true; members[msg.sender].y = block.timestamp;
        members[msg.sender].z = block.timestamp + 365 days;
        memberlist.push(msg.sender);
        a++;

        if (msg.value > b) {
            balances[msg.sender] += msg.value - b;
        }

        emit new_member(msg.sender, msg.value);
    }

    function renew_membership() external payable ismember(msg.sender) {
        require(msg.value >= b, "Insufficient payment");

        members[msg.sender].y = block.timestamp; members[msg.sender].z = block.timestamp + 365 days;

        if (msg.value > b) {
            balances[msg.sender] += msg.value - b;
        }

        emit renewal(msg.sender, msg.value);
    }

    function check_membership_status(address user) external view returns (bool active, uint256 expires) {
        temp1 memory m = members[user];
        return (m.x && block.timestamp <= m.z, m.z);
    }

    function withdraw_balance() external ismember(msg.sender) {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function update_fee(uint256 newfee) external onlyowner {
        b = newfee;
    }

    function get_member_count() external view returns (uint256) {
        return a;
    }

    function withdraw_contract_balance() external onlyowner {
        uint256 contractBalance = address(this).balance;
        uint256 totalMemberBalances = 0;

        for (uint256 i = 0; i < memberlist.length; i++) {
            totalMemberBalances += balances[memberlist[i]];
        }

        uint256 withdrawable = contractBalance - totalMemberBalances;
        require(withdrawable > 0, "No withdrawable funds");

        payable(owner).transfer(withdrawable);
    }

        function get_member_info(address user) external view returns (bool isMember, uint256 joinDate, uint256 expiryDate, uint256 balance) {
    temp1 memory info = members[user];
    return (info.x, info.y, info.z, balances[user]);
        }

    function transfer_ownership(address newowner) external onlyowner {
        require(newowner != address(0), "Invalid address");
        owner = newowner;
    }

    function emergency_pause_membership(address user) external onlyowner {
        members[user].x = false;
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
