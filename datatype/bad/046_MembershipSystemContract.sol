
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public totalMembers;
    uint256 public membershipFee;


    struct Member {
        uint256 memberId;
        string memberCode;
        uint256 membershipLevel;
        uint256 isActive;
        uint256 joinTimestamp;
        bytes memberData;
        uint256 pointsBalance;
        uint256 referralCount;
    }

    mapping(address => Member) public members;
    mapping(uint256 => address) public memberIdToAddress;
    mapping(string => address) public memberCodeToAddress;

    uint256 private nextMemberId = 1;


    event MemberRegistered(address indexed member, uint256 memberId, string memberCode, uint256 level);
    event MembershipLevelUpdated(address indexed member, uint256 oldLevel, uint256 newLevel);
    event PointsAwarded(address indexed member, uint256 points);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive == 1, "Only active members can call this function");
        _;
    }

    constructor(uint256 _membershipFee) {
        owner = msg.sender;
        membershipFee = _membershipFee;
        totalMembers = uint256(0);
    }

    function registerMember(string memory _memberCode, bytes memory _memberData) external payable {
        require(msg.value >= membershipFee, "Insufficient membership fee");
        require(members[msg.sender].isActive == 0, "Already a member");
        require(memberCodeToAddress[_memberCode] == address(0), "Member code already exists");

        uint256 memberId = nextMemberId;
        nextMemberId = uint256(nextMemberId + 1);

        members[msg.sender] = Member({
            memberId: memberId,
            memberCode: _memberCode,
            membershipLevel: uint256(1),
            isActive: uint256(1),
            joinTimestamp: block.timestamp,
            memberData: _memberData,
            pointsBalance: uint256(100),
            referralCount: uint256(0)
        });

        memberIdToAddress[memberId] = msg.sender;
        memberCodeToAddress[_memberCode] = msg.sender;
        totalMembers = uint256(totalMembers + 1);

        emit MemberRegistered(msg.sender, memberId, _memberCode, uint256(1));
    }

    function upgradeMembershipLevel() external onlyActiveMember {
        Member storage member = members[msg.sender];
        require(member.membershipLevel < uint256(5), "Already at maximum level");
        require(member.pointsBalance >= uint256(1000), "Insufficient points for upgrade");

        uint256 oldLevel = member.membershipLevel;
        member.membershipLevel = uint256(member.membershipLevel + 1);
        member.pointsBalance = uint256(member.pointsBalance - 1000);

        emit MembershipLevelUpdated(msg.sender, oldLevel, member.membershipLevel);
    }

    function awardPoints(address _member, uint256 _points) external onlyOwner {
        require(members[_member].isActive == 1, "Member is not active");

        members[_member].pointsBalance = uint256(members[_member].pointsBalance + _points);

        emit PointsAwarded(_member, _points);
    }

    function deactivateMember(address _member) external onlyOwner {
        require(members[_member].isActive == 1, "Member is already inactive");

        members[_member].isActive = uint256(0);
    }

    function reactivateMember(address _member) external onlyOwner {
        require(members[_member].memberId > uint256(0), "Member does not exist");
        require(members[_member].isActive == 0, "Member is already active");

        members[_member].isActive = uint256(1);
    }

    function addReferral(address _referrer) external onlyActiveMember {
        require(members[_referrer].isActive == 1, "Referrer is not active");
        require(_referrer != msg.sender, "Cannot refer yourself");

        members[_referrer].referralCount = uint256(members[_referrer].referralCount + 1);
        members[_referrer].pointsBalance = uint256(members[_referrer].pointsBalance + 50);

        emit PointsAwarded(_referrer, uint256(50));
    }

    function updateMemberData(bytes memory _newData) external onlyActiveMember {
        members[msg.sender].memberData = _newData;
    }

    function getMemberInfo(address _member) external view returns (
        uint256 memberId,
        string memory memberCode,
        uint256 membershipLevel,
        uint256 isActive,
        uint256 joinTimestamp,
        bytes memory memberData,
        uint256 pointsBalance,
        uint256 referralCount
    ) {
        Member memory member = members[_member];
        return (
            member.memberId,
            member.memberCode,
            member.membershipLevel,
            member.isActive,
            member.joinTimestamp,
            member.memberData,
            member.pointsBalance,
            member.referralCount
        );
    }

    function setMembershipFee(uint256 _newFee) external onlyOwner {
        membershipFee = _newFee;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > uint256(0), "No funds to withdraw");

        payable(owner).transfer(balance);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
