
pragma solidity ^0.8.0;


contract MembershipSystem {


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
        uint256 minimumSpent;
        uint256 minimumPoints;
    }


    address public contractOwner;
    mapping(address => MemberInfo) public members;
    mapping(MembershipTier => TierRequirement) public tierRequirements;
    mapping(address => bool) public authorizedOperators;

    uint256 public totalMembers;
    uint256 public pointsToEthRate;
    bool public systemActive;


    event MemberRegistered(address indexed memberAddress, string memberId, uint256 timestamp);
    event PointsEarned(address indexed memberAddress, uint256 points, string reason);
    event PointsRedeemed(address indexed memberAddress, uint256 points, uint256 ethAmount);
    event TierUpgraded(address indexed memberAddress, MembershipTier oldTier, MembershipTier newTier);
    event MembershipDeactivated(address indexed memberAddress, uint256 timestamp);
    event OperatorAuthorized(address indexed operator, bool status);


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAuthorizedOperator() {
        require(authorizedOperators[msg.sender] || msg.sender == contractOwner, "Not authorized operator");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Member account is not active");
        _;
    }

    modifier systemIsActive() {
        require(systemActive, "Membership system is currently inactive");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        systemActive = true;
        pointsToEthRate = 1000;


        tierRequirements[MembershipTier.BRONZE] = TierRequirement(0, 0);
        tierRequirements[MembershipTier.SILVER] = TierRequirement(1 ether, 1000);
        tierRequirements[MembershipTier.GOLD] = TierRequirement(5 ether, 5000);
        tierRequirements[MembershipTier.PLATINUM] = TierRequirement(10 ether, 15000);
        tierRequirements[MembershipTier.DIAMOND] = TierRequirement(50 ether, 50000);
    }


    function registerMember(string memory membershipId) external systemIsActive {
        require(!members[msg.sender].isActive, "Member already registered");
        require(bytes(membershipId).length > 0, "Membership ID cannot be empty");

        members[msg.sender] = MemberInfo({
            isActive: true,
            tier: MembershipTier.BRONZE,
            points: 0,
            totalSpent: 0,
            registrationTime: block.timestamp,
            lastActivityTime: block.timestamp,
            membershipId: membershipId
        });

        totalMembers++;

        emit MemberRegistered(msg.sender, membershipId, block.timestamp);
    }


    function addPoints(
        address memberAddress,
        uint256 pointsAmount,
        string memory reason
    ) external onlyAuthorizedOperator systemIsActive {
        require(members[memberAddress].isActive, "Member is not active");
        require(pointsAmount > 0, "Points amount must be greater than zero");

        members[memberAddress].points += pointsAmount;
        members[memberAddress].lastActivityTime = block.timestamp;


        _checkAndUpgradeTier(memberAddress);

        emit PointsEarned(memberAddress, pointsAmount, reason);
    }


    function recordPurchase(address memberAddress, uint256 spentAmount) external onlyAuthorizedOperator systemIsActive {
        require(members[memberAddress].isActive, "Member is not active");
        require(spentAmount > 0, "Spent amount must be greater than zero");

        members[memberAddress].totalSpent += spentAmount;
        members[memberAddress].lastActivityTime = block.timestamp;


        uint256 earnedPoints = spentAmount / (0.01 ether);
        if (earnedPoints > 0) {
            members[memberAddress].points += earnedPoints;
            emit PointsEarned(memberAddress, earnedPoints, "Purchase reward");
        }


        _checkAndUpgradeTier(memberAddress);
    }


    function redeemPoints(uint256 pointsAmount) external onlyActiveMember systemIsActive {
        require(pointsAmount > 0, "Points amount must be greater than zero");
        require(members[msg.sender].points >= pointsAmount, "Insufficient points balance");

        uint256 ethAmount = pointsAmount / pointsToEthRate;
        require(ethAmount > 0, "Points amount too small for redemption");
        require(address(this).balance >= ethAmount, "Contract has insufficient ETH balance");

        members[msg.sender].points -= pointsAmount;
        members[msg.sender].lastActivityTime = block.timestamp;

        payable(msg.sender).transfer(ethAmount);

        emit PointsRedeemed(msg.sender, pointsAmount, ethAmount);
    }


    function getMemberInfo(address memberAddress) external view returns (MemberInfo memory) {
        return members[memberAddress];
    }


    function _checkAndUpgradeTier(address memberAddress) internal {
        MemberInfo storage member = members[memberAddress];
        MembershipTier currentTier = member.tier;
        MembershipTier newTier = currentTier;


        if (member.totalSpent >= tierRequirements[MembershipTier.DIAMOND].minimumSpent &&
            member.points >= tierRequirements[MembershipTier.DIAMOND].minimumPoints) {
            newTier = MembershipTier.DIAMOND;
        } else if (member.totalSpent >= tierRequirements[MembershipTier.PLATINUM].minimumSpent &&
                   member.points >= tierRequirements[MembershipTier.PLATINUM].minimumPoints) {
            newTier = MembershipTier.PLATINUM;
        } else if (member.totalSpent >= tierRequirements[MembershipTier.GOLD].minimumSpent &&
                   member.points >= tierRequirements[MembershipTier.GOLD].minimumPoints) {
            newTier = MembershipTier.GOLD;
        } else if (member.totalSpent >= tierRequirements[MembershipTier.SILVER].minimumSpent &&
                   member.points >= tierRequirements[MembershipTier.SILVER].minimumPoints) {
            newTier = MembershipTier.SILVER;
        }


        if (newTier != currentTier) {
            member.tier = newTier;
            emit TierUpgraded(memberAddress, currentTier, newTier);
        }
    }


    function setOperatorAuthorization(address operatorAddress, bool status) external onlyOwner {
        require(operatorAddress != address(0), "Invalid operator address");
        authorizedOperators[operatorAddress] = status;
        emit OperatorAuthorized(operatorAddress, status);
    }


    function deactivateMember(address memberAddress) external onlyAuthorizedOperator {
        require(members[memberAddress].isActive, "Member is already inactive");
        members[memberAddress].isActive = false;
        emit MembershipDeactivated(memberAddress, block.timestamp);
    }


    function updatePointsToEthRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be greater than zero");
        pointsToEthRate = newRate;
    }


    function updateTierRequirement(
        MembershipTier tier,
        uint256 minimumSpent,
        uint256 minimumPoints
    ) external onlyOwner {
        tierRequirements[tier] = TierRequirement(minimumSpent, minimumPoints);
    }


    function setSystemStatus(bool status) external onlyOwner {
        systemActive = status;
    }


    function depositEth() external payable onlyOwner {
        require(msg.value > 0, "Deposit amount must be greater than zero");
    }


    function withdrawEth(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(contractOwner).transfer(amount);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        contractOwner = newOwner;
    }
}
