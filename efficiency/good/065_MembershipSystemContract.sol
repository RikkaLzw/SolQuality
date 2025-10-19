
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MembershipSystemContract is Ownable, ReentrancyGuard, Pausable {

    enum MembershipTier {
        NONE,
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM
    }


    struct MemberInfo {
        MembershipTier tier;
        uint256 joinTime;
        uint256 expiryTime;
        uint256 totalSpent;
        uint256 pointsBalance;
        bool isActive;
    }


    struct TierConfig {
        uint256 price;
        uint256 duration;
        uint256 pointsMultiplier;
        uint256 minSpendRequired;
    }


    mapping(address => MemberInfo) private members;
    mapping(MembershipTier => TierConfig) private tierConfigs;
    mapping(address => bool) private authorizedOperators;

    uint256 private totalMembers;
    uint256 private totalRevenue;
    address private treasuryAddress;


    event MembershipPurchased(address indexed member, MembershipTier tier, uint256 price, uint256 expiryTime);
    event MembershipUpgraded(address indexed member, MembershipTier fromTier, MembershipTier toTier);
    event MembershipRenewed(address indexed member, MembershipTier tier, uint256 newExpiryTime);
    event PointsAwarded(address indexed member, uint256 points, uint256 newBalance);
    event PointsRedeemed(address indexed member, uint256 points, uint256 remainingBalance);
    event TierConfigUpdated(MembershipTier tier, uint256 price, uint256 duration, uint256 pointsMultiplier);
    event OperatorAuthorized(address indexed operator, bool authorized);


    modifier onlyAuthorizedOperator() {
        require(authorizedOperators[msg.sender] || msg.sender == owner(), "Not authorized operator");
        _;
    }

    modifier validTier(MembershipTier _tier) {
        require(_tier != MembershipTier.NONE && _tier <= MembershipTier.PLATINUM, "Invalid tier");
        _;
    }

    modifier activeMember(address _member) {
        require(isMemberActive(_member), "Member not active");
        _;
    }

    constructor(address _treasuryAddress) {
        require(_treasuryAddress != address(0), "Invalid treasury address");
        treasuryAddress = _treasuryAddress;


        _initializeTierConfigs();
    }


    function _initializeTierConfigs() private {
        tierConfigs[MembershipTier.BRONZE] = TierConfig({
            price: 0.1 ether,
            duration: 30 days,
            pointsMultiplier: 1,
            minSpendRequired: 0
        });

        tierConfigs[MembershipTier.SILVER] = TierConfig({
            price: 0.25 ether,
            duration: 90 days,
            pointsMultiplier: 2,
            minSpendRequired: 1 ether
        });

        tierConfigs[MembershipTier.GOLD] = TierConfig({
            price: 0.5 ether,
            duration: 180 days,
            pointsMultiplier: 3,
            minSpendRequired: 5 ether
        });

        tierConfigs[MembershipTier.PLATINUM] = TierConfig({
            price: 1 ether,
            duration: 365 days,
            pointsMultiplier: 5,
            minSpendRequired: 10 ether
        });
    }


    function purchaseMembership(MembershipTier _tier)
        external
        payable
        nonReentrant
        whenNotPaused
        validTier(_tier)
    {
        TierConfig memory config = tierConfigs[_tier];
        require(msg.value >= config.price, "Insufficient payment");

        MemberInfo storage member = members[msg.sender];


        require(member.totalSpent >= config.minSpendRequired, "Insufficient total spending");

        uint256 newExpiryTime;
        bool isNewMember = member.tier == MembershipTier.NONE;

        if (isNewMember) {
            totalMembers++;
            member.joinTime = block.timestamp;
            newExpiryTime = block.timestamp + config.duration;
        } else if (member.expiryTime > block.timestamp) {

            newExpiryTime = member.expiryTime + config.duration;
        } else {

            newExpiryTime = block.timestamp + config.duration;
        }

        member.tier = _tier;
        member.expiryTime = newExpiryTime;
        member.isActive = true;

        totalRevenue += msg.value;


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }


        payable(treasuryAddress).transfer(config.price);

        emit MembershipPurchased(msg.sender, _tier, config.price, newExpiryTime);

        if (!isNewMember && _tier > member.tier) {
            emit MembershipUpgraded(msg.sender, member.tier, _tier);
        }
    }


    function renewMembership()
        external
        payable
        nonReentrant
        whenNotPaused
        activeMember(msg.sender)
    {
        MemberInfo storage member = members[msg.sender];
        TierConfig memory config = tierConfigs[member.tier];

        require(msg.value >= config.price, "Insufficient payment");

        uint256 newExpiryTime = member.expiryTime > block.timestamp
            ? member.expiryTime + config.duration
            : block.timestamp + config.duration;

        member.expiryTime = newExpiryTime;
        totalRevenue += msg.value;


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }


        payable(treasuryAddress).transfer(config.price);

        emit MembershipRenewed(msg.sender, member.tier, newExpiryTime);
    }


    function awardPoints(address _member, uint256 _basePoints)
        external
        onlyAuthorizedOperator
        activeMember(_member)
    {
        MemberInfo storage member = members[_member];
        TierConfig memory config = tierConfigs[member.tier];

        uint256 multipliedPoints = _basePoints * config.pointsMultiplier;
        member.pointsBalance += multipliedPoints;

        emit PointsAwarded(_member, multipliedPoints, member.pointsBalance);
    }


    function redeemPoints(uint256 _points)
        external
        activeMember(msg.sender)
    {
        MemberInfo storage member = members[msg.sender];
        require(member.pointsBalance >= _points, "Insufficient points");

        member.pointsBalance -= _points;

        emit PointsRedeemed(msg.sender, _points, member.pointsBalance);
    }


    function recordSpending(address _member, uint256 _amount)
        external
        onlyAuthorizedOperator
    {
        members[_member].totalSpent += _amount;
    }


    function isMemberActive(address _member) public view returns (bool) {
        MemberInfo memory member = members[_member];
        return member.isActive &&
               member.tier != MembershipTier.NONE &&
               member.expiryTime > block.timestamp;
    }


    function getMemberInfo(address _member)
        external
        view
        returns (
            MembershipTier tier,
            uint256 joinTime,
            uint256 expiryTime,
            uint256 totalSpent,
            uint256 pointsBalance,
            bool isActive
        )
    {
        MemberInfo memory member = members[_member];
        return (
            member.tier,
            member.joinTime,
            member.expiryTime,
            member.totalSpent,
            member.pointsBalance,
            isMemberActive(_member)
        );
    }


    function getTierConfig(MembershipTier _tier)
        external
        view
        returns (
            uint256 price,
            uint256 duration,
            uint256 pointsMultiplier,
            uint256 minSpendRequired
        )
    {
        TierConfig memory config = tierConfigs[_tier];
        return (
            config.price,
            config.duration,
            config.pointsMultiplier,
            config.minSpendRequired
        );
    }


    function batchCheckMemberStatus(address[] calldata _members)
        external
        view
        returns (bool[] memory activeStatuses)
    {
        uint256 length = _members.length;
        activeStatuses = new bool[](length);

        for (uint256 i = 0; i < length;) {
            activeStatuses[i] = isMemberActive(_members[i]);
            unchecked {
                ++i;
            }
        }
    }


    function updateTierConfig(
        MembershipTier _tier,
        uint256 _price,
        uint256 _duration,
        uint256 _pointsMultiplier,
        uint256 _minSpendRequired
    ) external onlyOwner validTier(_tier) {
        require(_price > 0 && _duration > 0 && _pointsMultiplier > 0, "Invalid config values");

        tierConfigs[_tier] = TierConfig({
            price: _price,
            duration: _duration,
            pointsMultiplier: _pointsMultiplier,
            minSpendRequired: _minSpendRequired
        });

        emit TierConfigUpdated(_tier, _price, _duration, _pointsMultiplier);
    }


    function setOperatorAuthorization(address _operator, bool _authorized)
        external
        onlyOwner
    {
        require(_operator != address(0), "Invalid operator address");
        authorizedOperators[_operator] = _authorized;
        emit OperatorAuthorized(_operator, _authorized);
    }


    function updateTreasuryAddress(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        treasuryAddress = _newTreasury;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function revokeMembership(address _member) external onlyOwner {
        MemberInfo storage member = members[_member];
        member.isActive = false;
        member.expiryTime = block.timestamp;
    }


    function getContractStats()
        external
        view
        returns (uint256 _totalMembers, uint256 _totalRevenue)
    {
        return (totalMembers, totalRevenue);
    }


    function isAuthorizedOperator(address _operator) external view returns (bool) {
        return authorizedOperators[_operator] || _operator == owner();
    }


    function getTreasuryAddress() external view returns (address) {
        return treasuryAddress;
    }
}
