
pragma solidity ^0.8.0;


contract MembershipSystemContract {


    enum MembershipTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        DIAMOND
    }


    struct MemberInfo {
        bool isActive;
        MembershipTier tier;
        uint256 points;
        uint256 totalSpent;
        uint256 registrationTime;
        uint256 lastActivityTime;
        string membershipId;
    }


    struct TierRequirement {
        uint256 minSpent;
        uint256 minPoints;
        uint256 discountRate;
        uint256 pointsMultiplier;
    }


    address public owner;
    uint256 public totalMembers;
    uint256 public membershipFee;
    bool public registrationOpen;


    mapping(address => MemberInfo) public members;
    mapping(MembershipTier => TierRequirement) public tierRequirements;
    mapping(string => address) public membershipIdToAddress;


    event MemberRegistered(address indexed member, string membershipId, uint256 timestamp);
    event MemberUpgraded(address indexed member, MembershipTier newTier, uint256 timestamp);
    event PointsEarned(address indexed member, uint256 points, uint256 timestamp);
    event PointsRedeemed(address indexed member, uint256 points, uint256 timestamp);
    event MembershipFeeUpdated(uint256 oldFee, uint256 newFee);
    event RegistrationStatusChanged(bool isOpen);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Only active members can call this function");
        _;
    }

    modifier registrationMustBeOpen() {
        require(registrationOpen, "Registration is currently closed");
        _;
    }


    constructor(uint256 _membershipFee) {
        owner = msg.sender;
        membershipFee = _membershipFee;
        registrationOpen = true;
        totalMembers = 0;


        _initializeTierRequirements();
    }


    function _initializeTierRequirements() private {
        tierRequirements[MembershipTier.BRONZE] = TierRequirement({
            minSpent: 0,
            minPoints: 0,
            discountRate: 1000,
            pointsMultiplier: 1
        });

        tierRequirements[MembershipTier.SILVER] = TierRequirement({
            minSpent: 1 ether,
            minPoints: 100,
            discountRate: 950,
            pointsMultiplier: 2
        });

        tierRequirements[MembershipTier.GOLD] = TierRequirement({
            minSpent: 5 ether,
            minPoints: 500,
            discountRate: 900,
            pointsMultiplier: 3
        });

        tierRequirements[MembershipTier.PLATINUM] = TierRequirement({
            minSpent: 10 ether,
            minPoints: 1000,
            discountRate: 850,
            pointsMultiplier: 4
        });

        tierRequirements[MembershipTier.DIAMOND] = TierRequirement({
            minSpent: 50 ether,
            minPoints: 5000,
            discountRate: 800,
            pointsMultiplier: 5
        });
    }


    function registerMember(string memory _membershipId) external payable registrationMustBeOpen {
        require(!members[msg.sender].isActive, "Already a member");
        require(msg.value >= membershipFee, "Insufficient membership fee");
        require(bytes(_membershipId).length > 0, "Membership ID cannot be empty");
        require(membershipIdToAddress[_membershipId] == address(0), "Membership ID already exists");


        members[msg.sender] = MemberInfo({
            isActive: true,
            tier: MembershipTier.BRONZE,
            points: 0,
            totalSpent: 0,
            registrationTime: block.timestamp,
            lastActivityTime: block.timestamp,
            membershipId: _membershipId
        });


        membershipIdToAddress[_membershipId] = msg.sender;
        totalMembers++;


        if (msg.value > membershipFee) {
            payable(msg.sender).transfer(msg.value - membershipFee);
        }

        emit MemberRegistered(msg.sender, _membershipId, block.timestamp);
    }


    function addPoints(address _member, uint256 _points) external onlyOwner {
        require(members[_member].isActive, "Member is not active");
        require(_points > 0, "Points must be greater than zero");

        MemberInfo storage member = members[_member];
        uint256 multiplier = tierRequirements[member.tier].pointsMultiplier;
        uint256 actualPoints = _points * multiplier;

        member.points += actualPoints;
        member.lastActivityTime = block.timestamp;

        emit PointsEarned(_member, actualPoints, block.timestamp);
    }


    function redeemPoints(uint256 _points) external onlyActiveMember {
        require(_points > 0, "Points must be greater than zero");
        require(members[msg.sender].points >= _points, "Insufficient points");

        members[msg.sender].points -= _points;
        members[msg.sender].lastActivityTime = block.timestamp;

        emit PointsRedeemed(msg.sender, _points, block.timestamp);
    }


    function recordPurchase(address _member, uint256 _amount) external onlyOwner {
        require(members[_member].isActive, "Member is not active");
        require(_amount > 0, "Amount must be greater than zero");

        MemberInfo storage member = members[_member];
        member.totalSpent += _amount;
        member.lastActivityTime = block.timestamp;


        _checkAndUpgradeTier(_member);


        uint256 earnedPoints = _amount / 1e16;
        if (earnedPoints > 0) {
            uint256 multiplier = tierRequirements[member.tier].pointsMultiplier;
            uint256 actualPoints = earnedPoints * multiplier;
            member.points += actualPoints;
            emit PointsEarned(_member, actualPoints, block.timestamp);
        }
    }


    function _checkAndUpgradeTier(address _member) private {
        MemberInfo storage member = members[_member];
        MembershipTier currentTier = member.tier;
        MembershipTier newTier = currentTier;


        if (_meetsRequirement(_member, MembershipTier.DIAMOND)) {
            newTier = MembershipTier.DIAMOND;
        } else if (_meetsRequirement(_member, MembershipTier.PLATINUM)) {
            newTier = MembershipTier.PLATINUM;
        } else if (_meetsRequirement(_member, MembershipTier.GOLD)) {
            newTier = MembershipTier.GOLD;
        } else if (_meetsRequirement(_member, MembershipTier.SILVER)) {
            newTier = MembershipTier.SILVER;
        }


        if (newTier != currentTier) {
            member.tier = newTier;
            emit MemberUpgraded(_member, newTier, block.timestamp);
        }
    }


    function _meetsRequirement(address _member, MembershipTier _tier) private view returns (bool) {
        MemberInfo storage member = members[_member];
        TierRequirement storage requirement = tierRequirements[_tier];

        return member.totalSpent >= requirement.minSpent && member.points >= requirement.minPoints;
    }


    function getMemberInfo(address _member) external view returns (MemberInfo memory) {
        return members[_member];
    }


    function getMemberDiscount(address _member) external view returns (uint256) {
        if (!members[_member].isActive) {
            return 1000;
        }
        return tierRequirements[members[_member].tier].discountRate;
    }


    function setMembershipFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = membershipFee;
        membershipFee = _newFee;
        emit MembershipFeeUpdated(oldFee, _newFee);
    }


    function setRegistrationStatus(bool _isOpen) external onlyOwner {
        registrationOpen = _isOpen;
        emit RegistrationStatusChanged(_isOpen);
    }


    function deactivateMember(address _member) external onlyOwner {
        require(members[_member].isActive, "Member is already inactive");
        members[_member].isActive = false;
    }


    function activateMember(address _member) external onlyOwner {
        require(!members[_member].isActive, "Member is already active");
        require(members[_member].registrationTime > 0, "Member does not exist");
        members[_member].isActive = true;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
