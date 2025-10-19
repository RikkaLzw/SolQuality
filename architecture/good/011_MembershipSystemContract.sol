
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library MembershipLib {
    struct Member {
        uint256 joinTime;
        uint256 expiryTime;
        uint8 tier;
        bool isActive;
        uint256 totalSpent;
        uint256 rewardPoints;
    }

    function isExpired(Member storage member) internal view returns (bool) {
        return block.timestamp > member.expiryTime;
    }

    function calculateRewardPoints(uint256 amount, uint8 tier) internal pure returns (uint256) {
        if (tier == 1) return amount / 100;
        if (tier == 2) return amount / 50;
        if (tier == 3) return amount / 25;
        return 0;
    }
}

contract MembershipSystemContract is Ownable, ReentrancyGuard, Pausable {
    using MembershipLib for MembershipLib.Member;


    uint256 public constant BASIC_MEMBERSHIP_FEE = 0.1 ether;
    uint256 public constant PREMIUM_MEMBERSHIP_FEE = 0.5 ether;
    uint256 public constant VIP_MEMBERSHIP_FEE = 1 ether;

    uint256 public constant BASIC_DURATION = 365 days;
    uint256 public constant PREMIUM_DURATION = 365 days;
    uint256 public constant VIP_DURATION = 365 days;

    uint8 public constant BASIC_TIER = 1;
    uint8 public constant PREMIUM_TIER = 2;
    uint8 public constant VIP_TIER = 3;


    mapping(address => MembershipLib.Member) private members;
    mapping(uint8 => uint256) private tierFees;
    mapping(uint8 => uint256) private tierDurations;

    uint256 private totalMembers;
    uint256 private totalRevenue;


    event MembershipPurchased(address indexed member, uint8 tier, uint256 expiryTime);
    event MembershipRenewed(address indexed member, uint8 tier, uint256 newExpiryTime);
    event MembershipUpgraded(address indexed member, uint8 fromTier, uint8 toTier);
    event RewardPointsEarned(address indexed member, uint256 points);
    event RewardPointsRedeemed(address indexed member, uint256 points);


    modifier onlyActiveMember() {
        require(isMember(msg.sender), "Not an active member");
        _;
    }

    modifier validTier(uint8 tier) {
        require(tier >= BASIC_TIER && tier <= VIP_TIER, "Invalid membership tier");
        _;
    }

    modifier notExpired(address memberAddress) {
        require(!members[memberAddress].isExpired(), "Membership has expired");
        _;
    }

    constructor() {
        _initializeTierSettings();
    }


    function _initializeTierSettings() private {
        tierFees[BASIC_TIER] = BASIC_MEMBERSHIP_FEE;
        tierFees[PREMIUM_TIER] = PREMIUM_MEMBERSHIP_FEE;
        tierFees[VIP_TIER] = VIP_MEMBERSHIP_FEE;

        tierDurations[BASIC_TIER] = BASIC_DURATION;
        tierDurations[PREMIUM_TIER] = PREMIUM_DURATION;
        tierDurations[VIP_TIER] = VIP_DURATION;
    }

    function _createMembership(address memberAddress, uint8 tier) private {
        uint256 expiryTime = block.timestamp + tierDurations[tier];

        members[memberAddress] = MembershipLib.Member({
            joinTime: block.timestamp,
            expiryTime: expiryTime,
            tier: tier,
            isActive: true,
            totalSpent: tierFees[tier],
            rewardPoints: 0
        });

        totalMembers++;
        totalRevenue += tierFees[tier];

        emit MembershipPurchased(memberAddress, tier, expiryTime);
    }

    function _renewMembership(address memberAddress, uint8 tier) private {
        MembershipLib.Member storage member = members[memberAddress];

        uint256 newExpiryTime;
        if (member.isExpired()) {
            newExpiryTime = block.timestamp + tierDurations[tier];
        } else {
            newExpiryTime = member.expiryTime + tierDurations[tier];
        }

        member.expiryTime = newExpiryTime;
        member.tier = tier;
        member.isActive = true;
        member.totalSpent += tierFees[tier];

        totalRevenue += tierFees[tier];

        emit MembershipRenewed(memberAddress, tier, newExpiryTime);
    }


    function purchaseMembership(uint8 tier)
        external
        payable
        validTier(tier)
        whenNotPaused
        nonReentrant
    {
        require(msg.value == tierFees[tier], "Incorrect payment amount");
        require(!isMember(msg.sender), "Already a member");

        _createMembership(msg.sender, tier);
    }

    function renewMembership(uint8 tier)
        external
        payable
        validTier(tier)
        whenNotPaused
        nonReentrant
    {
        require(msg.value == tierFees[tier], "Incorrect payment amount");
        require(members[msg.sender].joinTime > 0, "Not a member");

        _renewMembership(msg.sender, tier);
    }

    function upgradeMembership(uint8 newTier)
        external
        payable
        onlyActiveMember
        notExpired(msg.sender)
        validTier(newTier)
        whenNotPaused
        nonReentrant
    {
        MembershipLib.Member storage member = members[msg.sender];
        require(newTier > member.tier, "Can only upgrade to higher tier");

        uint256 upgradeFee = tierFees[newTier] - tierFees[member.tier];
        require(msg.value == upgradeFee, "Incorrect upgrade fee");

        uint8 oldTier = member.tier;
        member.tier = newTier;
        member.totalSpent += upgradeFee;

        totalRevenue += upgradeFee;

        emit MembershipUpgraded(msg.sender, oldTier, newTier);
    }

    function earnRewardPoints(address memberAddress, uint256 purchaseAmount)
        external
        onlyOwner
        whenNotPaused
    {
        require(isMember(memberAddress), "Not an active member");

        MembershipLib.Member storage member = members[memberAddress];
        uint256 points = MembershipLib.calculateRewardPoints(purchaseAmount, member.tier);

        member.rewardPoints += points;

        emit RewardPointsEarned(memberAddress, points);
    }

    function redeemRewardPoints(uint256 points)
        external
        onlyActiveMember
        notExpired(msg.sender)
        whenNotPaused
    {
        MembershipLib.Member storage member = members[msg.sender];
        require(member.rewardPoints >= points, "Insufficient reward points");

        member.rewardPoints -= points;

        emit RewardPointsRedeemed(msg.sender, points);
    }


    function isMember(address memberAddress) public view returns (bool) {
        MembershipLib.Member storage member = members[memberAddress];
        return member.isActive && !member.isExpired() && member.joinTime > 0;
    }

    function getMemberInfo(address memberAddress)
        external
        view
        returns (
            uint256 joinTime,
            uint256 expiryTime,
            uint8 tier,
            bool isActive,
            uint256 totalSpent,
            uint256 rewardPoints,
            bool isExpired
        )
    {
        MembershipLib.Member storage member = members[memberAddress];
        return (
            member.joinTime,
            member.expiryTime,
            member.tier,
            member.isActive,
            member.totalSpent,
            member.rewardPoints,
            member.isExpired()
        );
    }

    function getTierFee(uint8 tier) external view validTier(tier) returns (uint256) {
        return tierFees[tier];
    }

    function getTotalMembers() external view returns (uint256) {
        return totalMembers;
    }

    function getTotalRevenue() external view onlyOwner returns (uint256) {
        return totalRevenue;
    }


    function updateTierFee(uint8 tier, uint256 newFee)
        external
        onlyOwner
        validTier(tier)
    {
        tierFees[tier] = newFee;
    }

    function updateTierDuration(uint8 tier, uint256 newDuration)
        external
        onlyOwner
        validTier(tier)
    {
        tierDurations[tier] = newDuration;
    }

    function deactivateMember(address memberAddress) external onlyOwner {
        require(members[memberAddress].joinTime > 0, "Member does not exist");
        members[memberAddress].isActive = false;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    receive() external payable {
        revert("Direct payments not accepted");
    }
}
