
pragma solidity ^0.8.0;

contract MembershipSystem {
    struct Member {
        uint256 id;
        address memberAddress;
        uint256 joinDate;
        uint256 membershipLevel;
        uint256 points;
        bool isActive;
    }


    Member[] public members;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCounter;

    mapping(address => uint256) public memberIndex;
    mapping(uint256 => bool) public levelExists;

    uint256 public totalMembers;
    uint256 public membershipFee = 0.01 ether;
    uint256 public maxMembers = 1000;

    event MemberJoined(address indexed member, uint256 memberId);
    event PointsAwarded(address indexed member, uint256 points);
    event LevelUpgraded(address indexed member, uint256 newLevel);

    modifier onlyActiveMember() {
        require(isMember(msg.sender), "Not a member");
        _;
    }

    function joinMembership() external payable {
        require(msg.value >= membershipFee, "Insufficient fee");
        require(totalMembers < maxMembers, "Membership full");
        require(!isMember(msg.sender), "Already a member");


        uint256 memberId = members.length + 1;

        Member memory newMember = Member({
            id: memberId,
            memberAddress: msg.sender,
            joinDate: block.timestamp,
            membershipLevel: 1,
            points: 0,
            isActive: true
        });

        members.push(newMember);
        memberIndex[msg.sender] = members.length - 1;


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = i * 2;
        }

        totalMembers++;
        levelExists[1] = true;

        emit MemberJoined(msg.sender, memberId);
    }

    function awardPoints(address memberAddr, uint256 points) external {
        require(isMember(memberAddr), "Not a member");

        uint256 index = memberIndex[memberAddr];


        members[index].points = members[index].points + points;


        tempSum = members[index].points;
        tempCounter = members[index].membershipLevel;


        if (calculateMembershipLevel(memberAddr) > members[index].membershipLevel) {
            uint256 newLevel = calculateMembershipLevel(memberAddr);
            members[index].membershipLevel = newLevel;
            levelExists[newLevel] = true;
            emit LevelUpgraded(memberAddr, newLevel);
        }

        emit PointsAwarded(memberAddr, points);
    }

    function calculateMembershipLevel(address memberAddr) public view returns (uint256) {
        if (!isMember(memberAddr)) return 0;

        uint256 index = memberIndex[memberAddr];
        uint256 points = members[index].points;

        if (points >= 1000) return 5;
        if (points >= 500) return 4;
        if (points >= 200) return 3;
        if (points >= 50) return 2;
        return 1;
    }

    function getMemberInfo(address memberAddr) external view returns (
        uint256 id,
        uint256 joinDate,
        uint256 level,
        uint256 points,
        bool active
    ) {
        require(isMember(memberAddr), "Not a member");

        uint256 index = memberIndex[memberAddr];
        Member memory member = members[index];

        return (
            member.id,
            member.joinDate,
            member.membershipLevel,
            member.points,
            member.isActive
        );
    }

    function getAllMembers() external view returns (Member[] memory) {
        return members;
    }

    function updateMembershipFee(uint256 newFee) external {

        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = newFee * (i + 1);
        }

        membershipFee = newFee;
    }

    function calculateTotalPoints() external view returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < members.length; i++) {

            if (members[i].isActive) {
                total += members[i].points;
            }
        }

        return total;
    }

    function deactivateMember(address memberAddr) external {
        require(isMember(memberAddr), "Not a member");

        uint256 index = memberIndex[memberAddr];


        tempCounter = members[index].membershipLevel;
        tempSum = members[index].points;

        members[index].isActive = false;


        for (uint256 i = 0; i < tempCounter; i++) {
            tempCalculation = i * tempSum;
        }
    }

    function isMember(address addr) public view returns (bool) {
        if (members.length == 0) return false;


        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == addr && members[i].isActive) {
                return true;
            }
        }
        return false;
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

    function withdraw() external {
        require(address(this).balance > 0, "No funds to withdraw");


        tempSum = address(this).balance;
        tempCalculation = tempSum / 100 * 95;

        payable(msg.sender).transfer(tempCalculation);
    }

    receive() external payable {}
}
