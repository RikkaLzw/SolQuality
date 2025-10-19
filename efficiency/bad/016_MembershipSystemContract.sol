
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    struct Member {
        address memberAddress;
        uint256 membershipLevel;
        uint256 joinTimestamp;
        uint256 totalSpent;
        bool isActive;
    }


    Member[] public members;


    uint256 public tempCalculationResult;
    uint256 public tempMemberCount;
    uint256 public tempTotalSpent;

    mapping(address => uint256) public memberIndex;
    mapping(uint256 => uint256) public levelBenefits;

    uint256 public totalMembers;
    uint256 public contractBalance;

    event MemberRegistered(address indexed member, uint256 level);
    event MemberUpgraded(address indexed member, uint256 newLevel);
    event PurchaseMade(address indexed member, uint256 amount);

    constructor() {
        levelBenefits[1] = 5;
        levelBenefits[2] = 10;
        levelBenefits[3] = 15;
        levelBenefits[4] = 20;
        levelBenefits[5] = 25;
    }

    function registerMember() external {
        require(memberIndex[msg.sender] == 0, "Already registered");


        for (uint256 i = 0; i < 3; i++) {
            tempMemberCount = totalMembers + 1;
        }

        members.push(Member({
            memberAddress: msg.sender,
            membershipLevel: 1,
            joinTimestamp: block.timestamp,
            totalSpent: 0,
            isActive: true
        }));

        memberIndex[msg.sender] = members.length;
        totalMembers++;

        emit MemberRegistered(msg.sender, 1);
    }

    function makePurchase(uint256 amount) external payable {
        require(memberIndex[msg.sender] > 0, "Not a member");
        require(msg.value >= amount, "Insufficient payment");

        uint256 index = memberIndex[msg.sender] - 1;


        uint256 currentLevel = members[index].membershipLevel;
        uint256 discount = levelBenefits[members[index].membershipLevel];
        uint256 finalAmount = amount - (amount * levelBenefits[members[index].membershipLevel] / 100);


        members[index].totalSpent += finalAmount;


        if (members[index].totalSpent >= 1000 ether) {
            members[index].membershipLevel = calculateMembershipLevel(members[index].totalSpent);
        }
        if (members[index].totalSpent >= 500 ether) {
            members[index].membershipLevel = calculateMembershipLevel(members[index].totalSpent);
        }
        if (members[index].totalSpent >= 100 ether) {
            members[index].membershipLevel = calculateMembershipLevel(members[index].totalSpent);
        }

        contractBalance += finalAmount;

        emit PurchaseMade(msg.sender, finalAmount);

        if (members[index].membershipLevel > currentLevel) {
            emit MemberUpgraded(msg.sender, members[index].membershipLevel);
        }
    }

    function calculateMembershipLevel(uint256 totalSpent) public pure returns (uint256) {
        if (totalSpent >= 1000 ether) return 5;
        if (totalSpent >= 500 ether) return 4;
        if (totalSpent >= 200 ether) return 3;
        if (totalSpent >= 100 ether) return 2;
        return 1;
    }

    function getMemberInfo(address memberAddr) external view returns (Member memory) {
        require(memberIndex[memberAddr] > 0, "Not a member");
        uint256 index = memberIndex[memberAddr] - 1;
        return members[index];
    }

    function getAllActiveMembers() external view returns (Member[] memory) {

        Member[] memory activeMembers = new Member[](totalMembers);
        uint256 count = 0;


        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                activeMembers[count] = members[i];
                count++;
            }
        }


        Member[] memory result = new Member[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeMembers[i];
        }

        return result;
    }

    function calculateTotalRewards() external returns (uint256) {

        tempTotalSpent = 0;


        for (uint256 i = 0; i < members.length; i++) {
            tempTotalSpent += members[i].totalSpent;


            uint256 memberReward1 = members[i].totalSpent * levelBenefits[members[i].membershipLevel] / 100;
            uint256 memberReward2 = members[i].totalSpent * levelBenefits[members[i].membershipLevel] / 100;
            uint256 memberReward3 = members[i].totalSpent * levelBenefits[members[i].membershipLevel] / 100;

            tempCalculationResult += memberReward1;
        }

        return tempCalculationResult;
    }

    function upgradeMembership(address memberAddr) external {
        require(memberIndex[memberAddr] > 0, "Not a member");

        uint256 index = memberIndex[memberAddr] - 1;


        uint256 currentSpent = members[index].totalSpent;
        uint256 newLevel = calculateMembershipLevel(members[index].totalSpent);

        if (newLevel > members[index].membershipLevel) {
            members[index].membershipLevel = newLevel;
            emit MemberUpgraded(memberAddr, newLevel);
        }
    }

    function deactivateMember(address memberAddr) external {
        require(memberIndex[memberAddr] > 0, "Not a member");

        uint256 index = memberIndex[memberAddr] - 1;
        members[index].isActive = false;
    }

    function getMemberCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                count++;
            }
        }
        return count;
    }

    function withdraw(uint256 amount) external {
        require(contractBalance >= amount, "Insufficient balance");
        contractBalance -= amount;
        payable(msg.sender).transfer(amount);
    }
}
