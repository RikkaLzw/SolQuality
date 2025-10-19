
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public totalMembers;
    uint256 public membershipFee;


    struct Member {
        string memberId;
        uint256 membershipLevel;
        uint256 isActive;
        uint256 joinDate;
        uint256 expiryDate;
        bytes memberData;
        uint256 rewardPoints;
        uint256 isVip;
    }

    mapping(address => Member) public members;
    mapping(string => address) public memberIdToAddress;


    uint256 constant BASIC_LEVEL = 1;
    uint256 constant SILVER_LEVEL = 2;
    uint256 constant GOLD_LEVEL = 3;
    uint256 constant PLATINUM_LEVEL = 4;
    uint256 constant DIAMOND_LEVEL = 5;

    event MemberRegistered(address indexed member, string memberId, uint256 level);
    event MembershipRenewed(address indexed member, uint256 newExpiryDate);
    event MembershipUpgraded(address indexed member, uint256 newLevel);
    event RewardPointsAdded(address indexed member, uint256 points);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive == uint256(1), "Member is not active");
        _;
    }

    constructor(uint256 _membershipFee) {
        owner = msg.sender;
        membershipFee = _membershipFee;
        totalMembers = uint256(0);
    }

    function registerMember(
        string memory _memberId,
        bytes memory _memberData
    ) external payable {
        require(msg.value >= membershipFee, "Insufficient membership fee");
        require(memberIdToAddress[_memberId] == address(0), "Member ID already exists");
        require(members[msg.sender].isActive == uint256(0), "Already a member");


        uint256 currentTime = uint256(block.timestamp);
        uint256 expiryTime = currentTime + uint256(365 days);

        members[msg.sender] = Member({
            memberId: _memberId,
            membershipLevel: uint256(BASIC_LEVEL),
            isActive: uint256(1),
            joinDate: currentTime,
            expiryDate: expiryTime,
            memberData: _memberData,
            rewardPoints: uint256(100),
            isVip: uint256(0)
        });

        memberIdToAddress[_memberId] = msg.sender;
        totalMembers = totalMembers + uint256(1);

        emit MemberRegistered(msg.sender, _memberId, BASIC_LEVEL);
    }

    function renewMembership() external payable onlyActiveMember {
        require(msg.value >= membershipFee, "Insufficient renewal fee");

        uint256 currentExpiry = members[msg.sender].expiryDate;
        uint256 newExpiry;

        if (uint256(block.timestamp) > currentExpiry) {
            newExpiry = uint256(block.timestamp) + uint256(365 days);
        } else {
            newExpiry = currentExpiry + uint256(365 days);
        }

        members[msg.sender].expiryDate = newExpiry;

        emit MembershipRenewed(msg.sender, newExpiry);
    }

    function upgradeMembership(uint256 _newLevel) external payable onlyActiveMember {
        require(_newLevel > members[msg.sender].membershipLevel, "Cannot downgrade");
        require(_newLevel <= uint256(DIAMOND_LEVEL), "Invalid membership level");

        uint256 upgradeFee = (_newLevel - members[msg.sender].membershipLevel) * membershipFee;
        require(msg.value >= upgradeFee, "Insufficient upgrade fee");

        members[msg.sender].membershipLevel = _newLevel;


        if (_newLevel >= uint256(GOLD_LEVEL)) {
            members[msg.sender].isVip = uint256(1);
        }

        emit MembershipUpgraded(msg.sender, _newLevel);
    }

    function addRewardPoints(address _member, uint256 _points) external onlyOwner {
        require(members[_member].isActive == uint256(1), "Member is not active");

        members[_member].rewardPoints = members[_member].rewardPoints + _points;

        emit RewardPointsAdded(_member, _points);
    }

    function deactivateMember(address _member) external onlyOwner {
        require(members[_member].isActive == uint256(1), "Member already inactive");

        members[_member].isActive = uint256(0);
    }

    function updateMemberData(bytes memory _newData) external onlyActiveMember {
        members[msg.sender].memberData = _newData;
    }

    function getMemberInfo(address _member) external view returns (
        string memory memberId,
        uint256 membershipLevel,
        uint256 isActive,
        uint256 joinDate,
        uint256 expiryDate,
        uint256 rewardPoints,
        uint256 isVip
    ) {
        Member memory member = members[_member];
        return (
            member.memberId,
            member.membershipLevel,
            member.isActive,
            member.joinDate,
            member.expiryDate,
            member.rewardPoints,
            member.isVip
        );
    }

    function checkMembershipExpiry(address _member) external view returns (uint256) {
        if (members[_member].isActive == uint256(0)) {
            return uint256(0);
        }

        if (uint256(block.timestamp) > members[_member].expiryDate) {
            return uint256(0);
        }

        return uint256(1);
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
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
    }
}
