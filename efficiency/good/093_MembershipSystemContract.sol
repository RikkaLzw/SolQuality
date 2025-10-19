
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MembershipSystemContract is Ownable, ReentrancyGuard, Pausable {

    enum MemberTier { NONE, BRONZE, SILVER, GOLD, PLATINUM, DIAMOND }


    struct Member {
        MemberTier tier;
        uint256 joinTime;
        uint256 expiryTime;
        uint256 totalSpent;
        uint256 points;
        bool isActive;
    }


    struct TierConfig {
        uint256 price;
        uint256 duration;
        uint256 pointsMultiplier;
        uint256 discountRate;
        bool exists;
    }


    uint128 public totalMembers;
    uint128 public totalRevenue;


    mapping(address => Member) public members;
    mapping(MemberTier => TierConfig) public tierConfigs;
    mapping(address => bool) public authorizedOperators;


    event MembershipPurchased(address indexed member, MemberTier tier, uint256 price, uint256 expiryTime);
    event MembershipUpgraded(address indexed member, MemberTier fromTier, MemberTier toTier);
    event PointsEarned(address indexed member, uint256 points, uint256 totalPoints);
    event PointsRedeemed(address indexed member, uint256 points, uint256 remainingPoints);
    event TierConfigUpdated(MemberTier tier, uint256 price, uint256 duration);


    modifier onlyActiveMember() {
        Member storage member = members[msg.sender];
        require(member.isActive && block.timestamp < member.expiryTime, "Not an active member");
        _;
    }

    modifier onlyAuthorized() {
        require(owner() == msg.sender || authorizedOperators[msg.sender], "Not authorized");
        _;
    }

    constructor() {

        _initializeTierConfigs();
    }


    function _initializeTierConfigs() private {
        tierConfigs[MemberTier.BRONZE] = TierConfig(0.01 ether, 30 days, 100, 5, true);
        tierConfigs[MemberTier.SILVER] = TierConfig(0.05 ether, 90 days, 150, 10, true);
        tierConfigs[MemberTier.GOLD] = TierConfig(0.1 ether, 180 days, 200, 15, true);
        tierConfigs[MemberTier.PLATINUM] = TierConfig(0.2 ether, 365 days, 300, 20, true);
        tierConfigs[MemberTier.DIAMOND] = TierConfig(0.5 ether, 730 days, 500, 30, true);
    }


    function purchaseMembership(MemberTier _tier) external payable nonReentrant whenNotPaused {
        require(_tier != MemberTier.NONE, "Invalid tier");

        TierConfig memory config = tierConfigs[_tier];
        require(config.exists, "Tier not available");
        require(msg.value >= config.price, "Insufficient payment");

        Member storage member = members[msg.sender];


        uint256 newExpiryTime = member.isActive && block.timestamp < member.expiryTime
            ? member.expiryTime + config.duration
            : block.timestamp + config.duration;


        if (!member.isActive) {
            unchecked { ++totalMembers; }
        }

        member.tier = _tier;
        member.joinTime = member.joinTime == 0 ? block.timestamp : member.joinTime;
        member.expiryTime = newExpiryTime;
        member.isActive = true;

        unchecked { totalRevenue += uint128(msg.value); }


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }

        emit MembershipPurchased(msg.sender, _tier, config.price, newExpiryTime);
    }


    function upgradeMembership(MemberTier _newTier) external payable nonReentrant onlyActiveMember {
        Member storage member = members[msg.sender];
        require(_newTier > member.tier, "Can only upgrade to higher tier");

        TierConfig memory newConfig = tierConfigs[_newTier];
        TierConfig memory currentConfig = tierConfigs[member.tier];

        uint256 upgradeCost = newConfig.price - currentConfig.price;
        require(msg.value >= upgradeCost, "Insufficient upgrade payment");

        MemberTier oldTier = member.tier;
        member.tier = _newTier;

        unchecked { totalRevenue += uint128(upgradeCost); }

        if (msg.value > upgradeCost) {
            payable(msg.sender).transfer(msg.value - upgradeCost);
        }

        emit MembershipUpgraded(msg.sender, oldTier, _newTier);
    }


    function earnPoints(address _member, uint256 _basePoints) external onlyAuthorized {
        Member storage member = members[_member];
        require(member.isActive && block.timestamp < member.expiryTime, "Member not active");

        TierConfig memory config = tierConfigs[member.tier];
        uint256 earnedPoints = (_basePoints * config.pointsMultiplier) / 100;

        member.points += earnedPoints;

        emit PointsEarned(_member, earnedPoints, member.points);
    }


    function redeemPoints(uint256 _points) external onlyActiveMember {
        Member storage member = members[msg.sender];
        require(member.points >= _points, "Insufficient points");

        unchecked { member.points -= _points; }

        emit PointsRedeemed(msg.sender, _points, member.points);
    }


    function getMemberInfo(address _member) external view returns (
        MemberTier tier,
        uint256 joinTime,
        uint256 expiryTime,
        uint256 totalSpent,
        uint256 points,
        bool isActive,
        uint256 discountRate
    ) {
        Member memory member = members[_member];
        TierConfig memory config = tierConfigs[member.tier];

        return (
            member.tier,
            member.joinTime,
            member.expiryTime,
            member.totalSpent,
            member.points,
            member.isActive && block.timestamp < member.expiryTime,
            config.discountRate
        );
    }


    function isMemberActive(address _member) external view returns (bool) {
        Member memory member = members[_member];
        return member.isActive && block.timestamp < member.expiryTime;
    }


    function getMemberDiscount(address _member) external view returns (uint256) {
        Member memory member = members[_member];
        if (!member.isActive || block.timestamp >= member.expiryTime) {
            return 0;
        }
        return tierConfigs[member.tier].discountRate;
    }


    function updateTierConfig(
        MemberTier _tier,
        uint256 _price,
        uint256 _duration,
        uint256 _pointsMultiplier,
        uint256 _discountRate
    ) external onlyOwner {
        require(_tier != MemberTier.NONE, "Cannot configure NONE tier");
        require(_discountRate <= 50, "Discount rate too high");

        tierConfigs[_tier] = TierConfig(_price, _duration, _pointsMultiplier, _discountRate, true);

        emit TierConfigUpdated(_tier, _price, _duration);
    }


    function setAuthorizedOperator(address _operator, bool _authorized) external onlyOwner {
        authorizedOperators[_operator] = _authorized;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(owner()).transfer(_amount);
    }


    function batchUpdateMemberStatus(address[] calldata _members, bool[] calldata _statuses)
        external
        onlyOwner
    {
        require(_members.length == _statuses.length, "Array length mismatch");

        for (uint256 i = 0; i < _members.length;) {
            members[_members[i]].isActive = _statuses[i];
            unchecked { ++i; }
        }
    }


    function getContractStats() external view returns (
        uint256 totalMembersCount,
        uint256 totalRevenueAmount,
        uint256 contractBalance
    ) {
        return (totalMembers, totalRevenue, address(this).balance);
    }
}
