
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address owner;
    mapping(address => bool) members;
    mapping(address => uint256) membershipExpiry;
    mapping(address => uint256) membershipLevel;
    mapping(address => uint256) memberPoints;
    mapping(address => bool) premiumMembers;
    mapping(address => uint256) joinDate;
    mapping(address => string) memberNames;
    mapping(uint256 => address) memberByIndex;
    uint256 totalMembers;
    uint256 totalRevenue;
    mapping(address => uint256) membershipFees;
    mapping(address => bool) bannedMembers;
    mapping(address => uint256) lastActivityTime;

    event MemberJoined(address member, uint256 level);
    event MembershipRenewed(address member, uint256 newExpiry);
    event MemberUpgraded(address member, uint256 newLevel);
    event PointsAwarded(address member, uint256 points);
    event MemberBanned(address member);
    event MemberUnbanned(address member);

    constructor() {
        owner = msg.sender;
        totalMembers = 0;
        totalRevenue = 0;
    }

    function joinMembership(string memory name, uint256 level) public payable {

        if (members[msg.sender] == true) {
            revert("Already a member");
        }
        if (bannedMembers[msg.sender] == true) {
            revert("Banned from membership");
        }


        if (level == 1 && msg.value < 0.01 ether) {
            revert("Insufficient payment for basic membership");
        }
        if (level == 2 && msg.value < 0.05 ether) {
            revert("Insufficient payment for premium membership");
        }
        if (level == 3 && msg.value < 0.1 ether) {
            revert("Insufficient payment for VIP membership");
        }

        members[msg.sender] = true;
        membershipLevel[msg.sender] = level;
        memberNames[msg.sender] = name;
        joinDate[msg.sender] = block.timestamp;
        lastActivityTime[msg.sender] = block.timestamp;
        membershipFees[msg.sender] = msg.value;


        if (level == 1) {
            membershipExpiry[msg.sender] = block.timestamp + 2592000;
        }
        if (level == 2) {
            membershipExpiry[msg.sender] = block.timestamp + 7776000;
            premiumMembers[msg.sender] = true;
        }
        if (level == 3) {
            membershipExpiry[msg.sender] = block.timestamp + 31536000;
            premiumMembers[msg.sender] = true;
        }

        memberByIndex[totalMembers] = msg.sender;
        totalMembers++;
        totalRevenue += msg.value;

        emit MemberJoined(msg.sender, level);
    }

    function renewMembership() public payable {

        if (members[msg.sender] != true) {
            revert("Not a member");
        }
        if (bannedMembers[msg.sender] == true) {
            revert("Banned from membership");
        }

        uint256 currentLevel = membershipLevel[msg.sender];


        if (currentLevel == 1 && msg.value < 0.01 ether) {
            revert("Insufficient payment for basic membership renewal");
        }
        if (currentLevel == 2 && msg.value < 0.05 ether) {
            revert("Insufficient payment for premium membership renewal");
        }
        if (currentLevel == 3 && msg.value < 0.1 ether) {
            revert("Insufficient payment for VIP membership renewal");
        }

        lastActivityTime[msg.sender] = block.timestamp;
        membershipFees[msg.sender] += msg.value;


        if (currentLevel == 1) {
            membershipExpiry[msg.sender] = block.timestamp + 2592000;
        }
        if (currentLevel == 2) {
            membershipExpiry[msg.sender] = block.timestamp + 7776000;
        }
        if (currentLevel == 3) {
            membershipExpiry[msg.sender] = block.timestamp + 31536000;
        }

        totalRevenue += msg.value;

        emit MembershipRenewed(msg.sender, membershipExpiry[msg.sender]);
    }

    function upgradeMembership(uint256 newLevel) public payable {

        if (members[msg.sender] != true) {
            revert("Not a member");
        }
        if (bannedMembers[msg.sender] == true) {
            revert("Banned from membership");
        }

        uint256 currentLevel = membershipLevel[msg.sender];
        if (newLevel <= currentLevel) {
            revert("Can only upgrade to higher level");
        }


        if (newLevel == 2 && msg.value < 0.04 ether) {
            revert("Insufficient payment for premium upgrade");
        }
        if (newLevel == 3 && currentLevel == 1 && msg.value < 0.09 ether) {
            revert("Insufficient payment for VIP upgrade from basic");
        }
        if (newLevel == 3 && currentLevel == 2 && msg.value < 0.05 ether) {
            revert("Insufficient payment for VIP upgrade from premium");
        }

        membershipLevel[msg.sender] = newLevel;
        lastActivityTime[msg.sender] = block.timestamp;
        membershipFees[msg.sender] += msg.value;

        if (newLevel >= 2) {
            premiumMembers[msg.sender] = true;
        }


        if (newLevel == 2) {
            membershipExpiry[msg.sender] = block.timestamp + 7776000;
        }
        if (newLevel == 3) {
            membershipExpiry[msg.sender] = block.timestamp + 31536000;
        }

        totalRevenue += msg.value;

        emit MemberUpgraded(msg.sender, newLevel);
    }

    function awardPoints(address member, uint256 points) public {

        if (msg.sender != owner) {
            revert("Only owner can award points");
        }


        if (members[member] != true) {
            revert("Not a member");
        }
        if (bannedMembers[member] == true) {
            revert("Cannot award points to banned member");
        }
        if (membershipExpiry[member] < block.timestamp) {
            revert("Membership expired");
        }

        memberPoints[member] += points;
        lastActivityTime[member] = block.timestamp;

        emit PointsAwarded(member, points);
    }

    function banMember(address member) public {

        if (msg.sender != owner) {
            revert("Only owner can ban members");
        }


        if (members[member] != true) {
            revert("Not a member");
        }

        bannedMembers[member] = true;

        emit MemberBanned(member);
    }

    function unbanMember(address member) public {

        if (msg.sender != owner) {
            revert("Only owner can unban members");
        }

        bannedMembers[member] = false;

        emit MemberUnbanned(member);
    }

    function getMemberInfo(address member) public view returns (
        bool isMember,
        uint256 level,
        uint256 expiry,
        uint256 points,
        bool isPremium,
        string memory name,
        uint256 joinTime,
        bool isBanned
    ) {
        return (
            members[member],
            membershipLevel[member],
            membershipExpiry[member],
            memberPoints[member],
            premiumMembers[member],
            memberNames[member],
            joinDate[member],
            bannedMembers[member]
        );
    }

    function checkMembershipStatus(address member) public view returns (bool isActive) {

        if (members[member] != true) {
            return false;
        }
        if (bannedMembers[member] == true) {
            return false;
        }
        if (membershipExpiry[member] < block.timestamp) {
            return false;
        }
        return true;
    }

    function getContractStats() public view returns (
        uint256 totalMembersCount,
        uint256 totalRevenueAmount
    ) {
        return (totalMembers, totalRevenue);
    }

    function withdrawFunds() public {

        if (msg.sender != owner) {
            revert("Only owner can withdraw funds");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds to withdraw");
        }

        payable(owner).transfer(balance);
    }

    function updateMemberActivity(address member) public {

        if (msg.sender != owner) {
            revert("Only owner can update activity");
        }


        if (members[member] != true) {
            revert("Not a member");
        }
        if (bannedMembers[member] == true) {
            revert("Cannot update activity for banned member");
        }

        lastActivityTime[member] = block.timestamp;
    }

    function getMemberByIndex(uint256 index) public view returns (address) {
        if (index >= totalMembers) {
            revert("Index out of bounds");
        }
        return memberByIndex[index];
    }

    function changeOwner(address newOwner) public {

        if (msg.sender != owner) {
            revert("Only owner can change ownership");
        }

        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function bulkAwardPoints(address[] memory memberList, uint256 points) public {

        if (msg.sender != owner) {
            revert("Only owner can award points");
        }

        for (uint256 i = 0; i < memberList.length; i++) {
            address member = memberList[i];


            if (members[member] == true && bannedMembers[member] != true && membershipExpiry[member] >= block.timestamp) {
                memberPoints[member] += points;
                lastActivityTime[member] = block.timestamp;
                emit PointsAwarded(member, points);
            }
        }
    }
}
