
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public totalMembers;
    uint256 public totalRevenue;

    struct Member {
        bool isActive;
        uint256 membershipLevel;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
        string email;
        bool hasDiscount;
    }

    mapping(address => Member) public members;
    mapping(uint256 => address) public membersByIndex;
    mapping(address => bool) public admins;
    mapping(address => uint256) public memberRewards;
    mapping(uint256 => string) public levelNames;
    mapping(address => uint256[]) public memberTransactions;

    event MemberRegistered(address member, uint256 level);
    event MembershipUpgraded(address member, uint256 newLevel);
    event MembershipRenewed(address member, uint256 newExpiry);
    event RewardsClaimed(address member, uint256 amount);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
        levelNames[1] = "Bronze";
        levelNames[2] = "Silver";
        levelNames[3] = "Gold";
        levelNames[4] = "Platinum";
    }

    function registerMember(uint256 level, string memory email) public payable {

        if (level < 1 || level > 4) {
            revert("Invalid membership level");
        }
        if (level == 1 && msg.value < 100000000000000000) {
            revert("Insufficient payment for Bronze");
        }
        if (level == 2 && msg.value < 250000000000000000) {
            revert("Insufficient payment for Silver");
        }
        if (level == 3 && msg.value < 500000000000000000) {
            revert("Insufficient payment for Gold");
        }
        if (level == 4 && msg.value < 1000000000000000000) {
            revert("Insufficient payment for Platinum");
        }

        members[msg.sender] = Member({
            isActive: true,
            membershipLevel: level,
            joinDate: block.timestamp,
            expiryDate: block.timestamp + 31536000,
            totalSpent: msg.value,
            email: email,
            hasDiscount: false
        });

        membersByIndex[totalMembers] = msg.sender;
        totalMembers++;
        totalRevenue += msg.value;


        if (level == 1) {
            memberRewards[msg.sender] += 10;
        }
        if (level == 2) {
            memberRewards[msg.sender] += 25;
        }
        if (level == 3) {
            memberRewards[msg.sender] += 50;
        }
        if (level == 4) {
            memberRewards[msg.sender] += 100;
        }

        memberTransactions[msg.sender].push(msg.value);

        emit MemberRegistered(msg.sender, level);
    }

    function upgradeMembership(uint256 newLevel) public payable {

        if (newLevel < 1 || newLevel > 4) {
            revert("Invalid membership level");
        }
        if (newLevel == 1 && msg.value < 100000000000000000) {
            revert("Insufficient payment for Bronze");
        }
        if (newLevel == 2 && msg.value < 250000000000000000) {
            revert("Insufficient payment for Silver");
        }
        if (newLevel == 3 && msg.value < 500000000000000000) {
            revert("Insufficient payment for Gold");
        }
        if (newLevel == 4 && msg.value < 1000000000000000000) {
            revert("Insufficient payment for Platinum");
        }

        if (!members[msg.sender].isActive) {
            revert("Member not active");
        }
        if (newLevel <= members[msg.sender].membershipLevel) {
            revert("Can only upgrade to higher level");
        }

        members[msg.sender].membershipLevel = newLevel;
        members[msg.sender].totalSpent += msg.value;
        totalRevenue += msg.value;


        if (newLevel == 1) {
            memberRewards[msg.sender] += 10;
        }
        if (newLevel == 2) {
            memberRewards[msg.sender] += 25;
        }
        if (newLevel == 3) {
            memberRewards[msg.sender] += 50;
        }
        if (newLevel == 4) {
            memberRewards[msg.sender] += 100;
        }

        memberTransactions[msg.sender].push(msg.value);

        emit MembershipUpgraded(msg.sender, newLevel);
    }

    function renewMembership() public payable {
        if (!members[msg.sender].isActive) {
            revert("Member not active");
        }

        uint256 level = members[msg.sender].membershipLevel;


        if (level == 1 && msg.value < 80000000000000000) {
            revert("Insufficient payment for Bronze renewal");
        }
        if (level == 2 && msg.value < 200000000000000000) {
            revert("Insufficient payment for Silver renewal");
        }
        if (level == 3 && msg.value < 400000000000000000) {
            revert("Insufficient payment for Gold renewal");
        }
        if (level == 4 && msg.value < 800000000000000000) {
            revert("Insufficient payment for Platinum renewal");
        }

        members[msg.sender].expiryDate += 31536000;
        members[msg.sender].totalSpent += msg.value;
        totalRevenue += msg.value;

        memberTransactions[msg.sender].push(msg.value);

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryDate);
    }

    function claimRewards() public {
        if (!members[msg.sender].isActive) {
            revert("Member not active");
        }
        if (memberRewards[msg.sender] < 100) {
            revert("Insufficient rewards to claim");
        }

        uint256 rewardAmount = (memberRewards[msg.sender] * 1000000000000000) / 100;
        memberRewards[msg.sender] = 0;

        if (address(this).balance >= rewardAmount) {
            payable(msg.sender).transfer(rewardAmount);
            emit RewardsClaimed(msg.sender, rewardAmount);
        }
    }

    function addAdmin(address newAdmin) public {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert("Only owner or admin can add admins");
        }
        admins[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address adminToRemove) public {
        if (msg.sender != owner) {
            revert("Only owner can remove admins");
        }
        if (adminToRemove == owner) {
            revert("Cannot remove owner");
        }
        admins[adminToRemove] = false;
        emit AdminRemoved(adminToRemove);
    }

    function deactivateMember(address memberAddress) public {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert("Only owner or admin can deactivate members");
        }
        members[memberAddress].isActive = false;
    }

    function reactivateMember(address memberAddress) public {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert("Only owner or admin can reactivate members");
        }
        if (members[memberAddress].expiryDate < block.timestamp) {
            revert("Membership has expired, renewal required");
        }
        members[memberAddress].isActive = true;
    }

    function setMemberDiscount(address memberAddress, bool hasDiscount) public {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert("Only owner or admin can set discounts");
        }
        members[memberAddress].hasDiscount = hasDiscount;
    }

    function getMemberInfo(address memberAddress) public view returns (
        bool isActive,
        uint256 membershipLevel,
        uint256 joinDate,
        uint256 expiryDate,
        uint256 totalSpent,
        string memory email,
        bool hasDiscount,
        uint256 rewards
    ) {
        Member memory member = members[memberAddress];
        return (
            member.isActive,
            member.membershipLevel,
            member.joinDate,
            member.expiryDate,
            member.totalSpent,
            member.email,
            member.hasDiscount,
            memberRewards[memberAddress]
        );
    }

    function getMemberTransactions(address memberAddress) public view returns (uint256[] memory) {
        return memberTransactions[memberAddress];
    }

    function checkMembershipExpiry(address memberAddress) public view returns (bool isExpired) {
        return members[memberAddress].expiryDate < block.timestamp;
    }

    function calculateMembershipValue(address memberAddress) public view returns (uint256) {
        Member memory member = members[memberAddress];
        if (!member.isActive) {
            return 0;
        }


        uint256 baseValue = 0;
        if (member.membershipLevel == 1) {
            baseValue = 100;
        }
        if (member.membershipLevel == 2) {
            baseValue = 250;
        }
        if (member.membershipLevel == 3) {
            baseValue = 500;
        }
        if (member.membershipLevel == 4) {
            baseValue = 1000;
        }

        uint256 loyaltyBonus = 0;
        uint256 membershipDuration = block.timestamp - member.joinDate;
        if (membershipDuration > 31536000) {
            loyaltyBonus = 50;
        }
        if (membershipDuration > 63072000) {
            loyaltyBonus = 100;
        }
        if (membershipDuration > 94608000) {
            loyaltyBonus = 200;
        }

        return baseValue + loyaltyBonus + memberRewards[memberAddress];
    }

    function bulkProcessMembers(address[] memory memberAddresses, bool[] memory activationStatus) public {
        if (msg.sender != owner && !admins[msg.sender]) {
            revert("Only owner or admin can bulk process");
        }
        if (memberAddresses.length != activationStatus.length) {
            revert("Arrays length mismatch");
        }

        for (uint256 i = 0; i < memberAddresses.length; i++) {
            members[memberAddresses[i]].isActive = activationStatus[i];
        }
    }

    function emergencyWithdraw() public {
        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }
        payable(owner).transfer(address(this).balance);
    }

    function updateMemberEmail(string memory newEmail) public {
        if (!members[msg.sender].isActive) {
            revert("Member not active");
        }
        members[msg.sender].email = newEmail;
    }

    function getMembershipLevelName(uint256 level) public view returns (string memory) {
        return levelNames[level];
    }

    function getTotalActiveMembers() public view returns (uint256) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < totalMembers; i++) {
            if (members[membersByIndex[i]].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        totalRevenue += msg.value;
    }

    fallback() external payable {
        totalRevenue += msg.value;
    }
}
