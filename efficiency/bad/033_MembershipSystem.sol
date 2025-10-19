
pragma solidity ^0.8.0;

contract MembershipSystem {
    struct Member {
        address memberAddress;
        uint256 joinTime;
        uint256 membershipLevel;
        bool isActive;
        uint256 totalSpent;
        uint256 rewardPoints;
    }


    Member[] public members;


    mapping(address => uint256) public memberIndex;
    mapping(address => bool) public isMember;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCount;

    address public owner;
    uint256 public totalMembers;
    uint256 public membershipFee = 0.1 ether;

    event MemberJoined(address indexed member, uint256 timestamp);
    event MembershipLevelUpdated(address indexed member, uint256 newLevel);
    event RewardPointsAdded(address indexed member, uint256 points);

    constructor() {
        owner = msg.sender;

        members.push(Member(address(0), 0, 0, false, 0, 0));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");
        _;
    }

    function joinMembership() external payable {
        require(msg.value >= membershipFee, "Insufficient membership fee");
        require(!isMember[msg.sender], "Already a member");


        totalMembers = totalMembers + 1;

        Member memory newMember = Member({
            memberAddress: msg.sender,
            joinTime: block.timestamp,
            membershipLevel: 1,
            isActive: true,
            totalSpent: msg.value,
            rewardPoints: msg.value / 1e15
        });

        members.push(newMember);
        memberIndex[msg.sender] = members.length - 1;
        isMember[msg.sender] = true;

        emit MemberJoined(msg.sender, block.timestamp);
    }

    function purchaseWithRewards(uint256 amount) external payable onlyMember {
        require(msg.value >= amount, "Insufficient payment");

        uint256 index = memberIndex[msg.sender];


        for(uint256 i = 0; i < 5; i++) {
            tempCalculation = amount * (i + 1);
            members[index].totalSpent += tempCalculation / 5;
        }


        uint256 rewardPoints1 = calculateRewardPoints(amount);
        uint256 rewardPoints2 = calculateRewardPoints(amount);
        uint256 rewardPoints3 = calculateRewardPoints(amount);

        members[index].rewardPoints += (rewardPoints1 + rewardPoints2 + rewardPoints3) / 3;


        if(members[index].totalSpent > 1 ether && members[index].membershipLevel < 2) {
            members[index].membershipLevel = 2;
            emit MembershipLevelUpdated(msg.sender, members[index].membershipLevel);
        }
        if(members[index].totalSpent > 5 ether && members[index].membershipLevel < 3) {
            members[index].membershipLevel = 3;
            emit MembershipLevelUpdated(msg.sender, members[index].membershipLevel);
        }
        if(members[index].totalSpent > 10 ether && members[index].membershipLevel < 4) {
            members[index].membershipLevel = 4;
            emit MembershipLevelUpdated(msg.sender, members[index].membershipLevel);
        }

        emit RewardPointsAdded(msg.sender, members[index].rewardPoints);
    }

    function calculateRewardPoints(uint256 amount) public view returns (uint256) {

        if(amount < 0.1 ether) {
            return amount / 1e15;
        } else if(amount < 1 ether) {
            return (amount / 1e15) * 2;
        } else {
            return (amount / 1e15) * 3;
        }
    }

    function getMemberInfo(address memberAddr) external view returns (
        uint256 joinTime,
        uint256 membershipLevel,
        bool isActive,
        uint256 totalSpent,
        uint256 rewardPoints
    ) {
        require(isMember[memberAddr], "Not a member");

        uint256 index = memberIndex[memberAddr];
        Member storage member = members[index];

        return (
            member.joinTime,
            member.membershipLevel,
            member.isActive,
            member.totalSpent,
            member.rewardPoints
        );
    }

    function getAllMembersCount() external view returns (uint256) {

        uint256 count = 0;
        for(uint256 i = 1; i < members.length; i++) {
            if(members[i].isActive) {
                count++;
            }
        }
        return count;
    }

    function calculateTotalRewards() external onlyOwner {

        tempSum = 0;
        tempCount = 0;


        for(uint256 i = 1; i < members.length; i++) {
            if(members[i].isActive) {
                tempSum += members[i].rewardPoints;
                tempCount++;

                tempCalculation = tempSum / (tempCount > 0 ? tempCount : 1);
            }
        }
    }

    function updateMembershipFee(uint256 newFee) external onlyOwner {
        membershipFee = newFee;
    }

    function deactivateMember(address memberAddr) external onlyOwner {
        require(isMember[memberAddr], "Not a member");

        uint256 index = memberIndex[memberAddr];
        members[index].isActive = false;
    }

    function withdrawFunds() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function getMembershipLevel(address memberAddr) external view returns (uint256) {
        require(isMember[memberAddr], "Not a member");


        uint256 index = memberIndex[memberAddr];
        if(members[index].isActive && members[index].membershipLevel > 0) {
            return members[index].membershipLevel;
        }
        return 0;
    }
}
