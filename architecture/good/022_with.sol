
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract MembershipSystem is Ownable, ReentrancyGuard, Pausable {

    uint256 public constant BASIC_MEMBERSHIP_PRICE = 0.01 ether;
    uint256 public constant PREMIUM_MEMBERSHIP_PRICE = 0.05 ether;
    uint256 public constant VIP_MEMBERSHIP_PRICE = 0.1 ether;

    uint256 public constant BASIC_DURATION = 30 days;
    uint256 public constant PREMIUM_DURATION = 90 days;
    uint256 public constant VIP_DURATION = 365 days;

    uint256 public constant MAX_REFERRAL_BONUS = 20;
    uint256 public constant PLATFORM_FEE = 5;


    enum MembershipTier { None, Basic, Premium, VIP }


    struct Member {
        MembershipTier tier;
        uint256 expirationTime;
        uint256 joinTime;
        address referrer;
        uint256 totalSpent;
        uint256 referralEarnings;
        bool isActive;
    }

    struct MembershipConfig {
        uint256 price;
        uint256 duration;
        uint256 maxDiscount;
        bool isActive;
    }


    mapping(address => Member) public members;
    mapping(MembershipTier => MembershipConfig) public membershipConfigs;
    mapping(address => address[]) public referrals;

    uint256 public totalMembers;
    uint256 public totalRevenue;
    address public treasury;


    event MembershipPurchased(
        address indexed member,
        MembershipTier tier,
        uint256 price,
        uint256 expirationTime,
        address indexed referrer
    );

    event MembershipRenewed(
        address indexed member,
        MembershipTier tier,
        uint256 newExpirationTime
    );

    event MembershipUpgraded(
        address indexed member,
        MembershipTier fromTier,
        MembershipTier toTier
    );

    event ReferralBonus(
        address indexed referrer,
        address indexed referee,
        uint256 bonus
    );

    event ConfigUpdated(
        MembershipTier tier,
        uint256 price,
        uint256 duration,
        uint256 maxDiscount
    );


    modifier onlyMember() {
        require(isMemberActive(msg.sender), "Not an active member");
        _;
    }

    modifier onlyTierOrAbove(MembershipTier requiredTier) {
        require(
            members[msg.sender].tier >= requiredTier && isMemberActive(msg.sender),
            "Insufficient membership tier"
        );
        _;
    }

    modifier validTier(MembershipTier tier) {
        require(
            tier != MembershipTier.None && membershipConfigs[tier].isActive,
            "Invalid or inactive tier"
        );
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor(address _treasury) validAddress(_treasury) {
        treasury = _treasury;
        _initializeMembershipConfigs();
    }


    function _initializeMembershipConfigs() private {
        membershipConfigs[MembershipTier.Basic] = MembershipConfig({
            price: BASIC_MEMBERSHIP_PRICE,
            duration: BASIC_DURATION,
            maxDiscount: 5,
            isActive: true
        });

        membershipConfigs[MembershipTier.Premium] = MembershipConfig({
            price: PREMIUM_MEMBERSHIP_PRICE,
            duration: PREMIUM_DURATION,
            maxDiscount: 10,
            isActive: true
        });

        membershipConfigs[MembershipTier.VIP] = MembershipConfig({
            price: VIP_MEMBERSHIP_PRICE,
            duration: VIP_DURATION,
            maxDiscount: 20,
            isActive: true
        });
    }


    function purchaseMembership(
        MembershipTier tier,
        address referrer
    ) external payable nonReentrant whenNotPaused validTier(tier) {
        require(!isMemberActive(msg.sender), "Already have active membership");

        MembershipConfig memory config = membershipConfigs[tier];
        require(msg.value >= config.price, "Insufficient payment");


        if (referrer != address(0)) {
            require(referrer != msg.sender, "Cannot refer yourself");
            require(isMemberActive(referrer), "Referrer must be active member");
        }


        members[msg.sender] = Member({
            tier: tier,
            expirationTime: block.timestamp + config.duration,
            joinTime: block.timestamp,
            referrer: referrer,
            totalSpent: config.price,
            referralEarnings: 0,
            isActive: true
        });

        totalMembers++;
        totalRevenue += config.price;


        if (referrer != address(0)) {
            _processReferralBonus(referrer, config.price);
            referrals[referrer].push(msg.sender);
        }


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }

        emit MembershipPurchased(
            msg.sender,
            tier,
            config.price,
            members[msg.sender].expirationTime,
            referrer
        );
    }


    function renewMembership() external payable nonReentrant whenNotPaused {
        Member storage member = members[msg.sender];
        require(member.tier != MembershipTier.None, "No existing membership");

        MembershipConfig memory config = membershipConfigs[member.tier];
        require(msg.value >= config.price, "Insufficient payment");


        if (member.expirationTime > block.timestamp) {
            member.expirationTime += config.duration;
        } else {
            member.expirationTime = block.timestamp + config.duration;
        }

        member.isActive = true;
        member.totalSpent += config.price;
        totalRevenue += config.price;


        if (member.referrer != address(0) && isMemberActive(member.referrer)) {
            _processReferralBonus(member.referrer, config.price);
        }


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }

        emit MembershipRenewed(msg.sender, member.tier, member.expirationTime);
    }


    function upgradeMembership(
        MembershipTier newTier
    ) external payable nonReentrant whenNotPaused validTier(newTier) onlyMember {
        Member storage member = members[msg.sender];
        require(newTier > member.tier, "Can only upgrade to higher tier");

        MembershipConfig memory currentConfig = membershipConfigs[member.tier];
        MembershipConfig memory newConfig = membershipConfigs[newTier];

        uint256 upgradeCost = _calculateUpgradeCost(member.tier, newTier);
        require(msg.value >= upgradeCost, "Insufficient payment for upgrade");

        MembershipTier oldTier = member.tier;
        member.tier = newTier;
        member.totalSpent += upgradeCost;


        uint256 remainingTime = member.expirationTime > block.timestamp
            ? member.expirationTime - block.timestamp
            : 0;
        member.expirationTime = block.timestamp + newConfig.duration + remainingTime;

        totalRevenue += upgradeCost;


        if (member.referrer != address(0) && isMemberActive(member.referrer)) {
            _processReferralBonus(member.referrer, upgradeCost);
        }


        if (msg.value > upgradeCost) {
            payable(msg.sender).transfer(msg.value - upgradeCost);
        }

        emit MembershipUpgraded(msg.sender, oldTier, newTier);
    }


    function _calculateUpgradeCost(
        MembershipTier currentTier,
        MembershipTier newTier
    ) private view returns (uint256) {
        return membershipConfigs[newTier].price - membershipConfigs[currentTier].price;
    }


    function _processReferralBonus(address referrer, uint256 amount) private {
        uint256 bonus = (amount * MAX_REFERRAL_BONUS) / 100;
        members[referrer].referralEarnings += bonus;

        payable(referrer).transfer(bonus);
        emit ReferralBonus(referrer, msg.sender, bonus);
    }


    function isMemberActive(address member) public view returns (bool) {
        return members[member].isActive &&
               members[member].expirationTime > block.timestamp &&
               members[member].tier != MembershipTier.None;
    }


    function getMemberInfo(address member) external view returns (
        MembershipTier tier,
        uint256 expirationTime,
        uint256 joinTime,
        address referrer,
        uint256 totalSpent,
        uint256 referralEarnings,
        bool isActive
    ) {
        Member memory memberInfo = members[member];
        return (
            memberInfo.tier,
            memberInfo.expirationTime,
            memberInfo.joinTime,
            memberInfo.referrer,
            memberInfo.totalSpent,
            memberInfo.referralEarnings,
            isMemberActive(member)
        );
    }


    function getReferrals(address member) external view returns (address[] memory) {
        return referrals[member];
    }


    function getMemberDiscount(address member) external view returns (uint256) {
        if (!isMemberActive(member)) return 0;
        return membershipConfigs[members[member].tier].maxDiscount;
    }


    function updateMembershipConfig(
        MembershipTier tier,
        uint256 price,
        uint256 duration,
        uint256 maxDiscount,
        bool isActive
    ) external onlyOwner validTier(tier) {
        require(price > 0, "Price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(maxDiscount <= 50, "Discount cannot exceed 50%");

        membershipConfigs[tier] = MembershipConfig({
            price: price,
            duration: duration,
            maxDiscount: maxDiscount,
            isActive: isActive
        });

        emit ConfigUpdated(tier, price, duration, maxDiscount);
    }

    function updateTreasury(address newTreasury) external onlyOwner validAddress(newTreasury) {
        treasury = newTreasury;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(treasury).transfer(balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deactivateMember(address member) external onlyOwner {
        members[member].isActive = false;
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
