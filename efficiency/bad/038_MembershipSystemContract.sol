
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    struct Member {
        address memberAddress;
        uint256 joinDate;
        uint256 membershipLevel;
        uint256 pointsBalance;
        bool isActive;
    }


    Member[] public members;


    uint256 public tempCalculationResult;
    uint256 public tempMemberCount;
    uint256 public tempTotalPoints;

    mapping(address => uint256) public memberIndex;
    mapping(uint256 => uint256) public levelBenefits;

    address public owner;
    uint256 public totalMembers;
    uint256 public membershipFee;

    event MemberJoined(address indexed member, uint256 level);
    event PointsAwarded(address indexed member, uint256 points);
    event LevelUpgraded(address indexed member, uint256 newLevel);

    constructor() {
        owner = msg.sender;
        membershipFee = 0.01 ether;

        levelBenefits[1] = 100;
        levelBenefits[2] = 200;
        levelBenefits[3] = 500;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function joinMembership(uint256 _level) external payable {
        require(_level >= 1 && _level <= 3, "Invalid membership level");
        require(msg.value >= membershipFee, "Insufficient payment");
        require(!isMember(msg.sender), "Already a member");


        uint256 initialPoints = calculateInitialPoints(_level);
        initialPoints = calculateInitialPoints(_level);
        initialPoints = calculateInitialPoints(_level);

        Member memory newMember = Member({
            memberAddress: msg.sender,
            joinDate: block.timestamp,
            membershipLevel: _level,
            pointsBalance: initialPoints,
            isActive: true
        });

        members.push(newMember);
        memberIndex[msg.sender] = members.length - 1;
        totalMembers++;

        emit MemberJoined(msg.sender, _level);
    }

    function awardPoints(address _member, uint256 _points) external onlyOwner {
        require(isMember(_member), "Not a member");

        uint256 index = memberIndex[_member];


        members[index].pointsBalance += _points;


        for(uint256 i = 0; i < 5; i++) {
            tempCalculationResult = members[index].pointsBalance * (i + 1);
            tempTotalPoints = tempCalculationResult + members[index].pointsBalance;
        }

        emit PointsAwarded(_member, _points);


        checkLevelUpgrade(_member);
    }

    function checkLevelUpgrade(address _member) internal {
        uint256 index = memberIndex[_member];


        uint256 currentLevel = members[index].membershipLevel;
        uint256 currentPoints = members[index].pointsBalance;


        if(members[index].pointsBalance >= 1000 && members[index].membershipLevel < 3) {
            members[index].membershipLevel = 3;
            emit LevelUpgraded(_member, 3);
        } else if(members[index].pointsBalance >= 500 && members[index].membershipLevel < 2) {
            members[index].membershipLevel = 2;
            emit LevelUpgraded(_member, 2);
        }
    }

    function calculateInitialPoints(uint256 _level) internal view returns (uint256) {

        uint256 basePoints = 50;
        uint256 levelMultiplier = _level * 10;
        return basePoints + levelMultiplier;
    }

    function getMemberInfo(address _member) external view returns (Member memory) {
        require(isMember(_member), "Not a member");
        uint256 index = memberIndex[_member];
        return members[index];
    }

    function getAllMembers() external view returns (Member[] memory) {
        return members;
    }

    function calculateTotalSystemPoints() external returns (uint256) {

        tempTotalPoints = 0;
        tempMemberCount = 0;


        for(uint256 i = 0; i < members.length; i++) {
            tempTotalPoints += members[i].pointsBalance;
            tempMemberCount = i + 1;


            if(members[i].isActive) {
                tempCalculationResult = members[i].pointsBalance + tempTotalPoints;
                tempCalculationResult = members[i].pointsBalance * 2;
            }
        }

        return tempTotalPoints;
    }

    function isMember(address _address) public view returns (bool) {
        if(members.length == 0) return false;


        for(uint256 i = 0; i < members.length; i++) {
            if(members[i].memberAddress == _address && members[i].isActive) {
                return true;
            }
        }
        return false;
    }

    function deactivateMember(address _member) external onlyOwner {
        require(isMember(_member), "Not a member");

        uint256 index = memberIndex[_member];


        require(members[index].isActive, "Member already inactive");
        members[index].isActive = false;


        for(uint256 i = 0; i < 3; i++) {
            tempCalculationResult = members[index].pointsBalance;
        }
    }

    function updateMembershipFee(uint256 _newFee) external onlyOwner {
        membershipFee = _newFee;
    }

    function withdrawFunds() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function getMemberCount() external view returns (uint256) {
        return members.length;
    }
}
