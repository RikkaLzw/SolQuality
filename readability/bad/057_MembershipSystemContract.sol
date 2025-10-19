
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public a;
    uint256 public b = 100 ether;

    struct temp1 {
        bool x;
        uint256 y;
        uint256 z;
    }

    mapping(address => temp1) public members;
    mapping(uint256 => address) public memberList;

    event something_happened(address indexed user, uint256 level);
    event fee_changed(uint256 newFee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validMember() {
        require(members[msg.sender].x == true, "Not member");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function join_membership() external payable {
        require(msg.value >= b, "Insufficient payment");
        require(members[msg.sender].x == false, "Already member");

        members[msg.sender] = temp1(true, block.timestamp, 1);
        memberList[a] = msg.sender; a++;

        emit something_happened(msg.sender, 1);

        if (msg.value > b) {
            payable(msg.sender).transfer(msg.value - b);
        }
    }

    function upgrade_level() external payable validMember {
        uint256 c = members[msg.sender].z;
        require(c < 5, "Max level reached");

        uint256 d = c * 50 ether;
        require(msg.value >= d, "Insufficient payment");

        members[msg.sender].z = c + 1;
        emit something_happened(msg.sender, c + 1);

        if (msg.value > d) {
            payable(msg.sender).transfer(msg.value - d);
        }
    }

    function cancel_membership() external validMember {
        members[msg.sender].x = false;
        members[msg.sender].z = 0;
    }

    function set_fee(uint256 newFee) external onlyOwner {
        b = newFee; emit fee_changed(newFee);
    }

    function get_member_info(address user) external view returns (bool, uint256, uint256) {
        temp1 memory m = members[user];
        return (m.x, m.y, m.z);
    }

    function withdraw_funds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        payable(owner).transfer(balance);
    }

    function transfer_ownership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

        function get_total_members() external view returns (uint256) {
    return a;
        }

    function is_member(address user) external view returns (bool) {
        return members[user].x;
    }

    receive() external payable {}
}
