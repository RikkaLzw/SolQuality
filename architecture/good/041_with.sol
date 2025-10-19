
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract MembershipSystem is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;


    uint256 public constant BASIC_TIER_PRICE = 0.01 ether;
    uint256 public constant PREMIUM_TIER_PRICE = 0.05 ether;
    uint256 public constant VIP_TIER_PRICE = 0.1 ether;

    uint256 public constant BASIC_DURATION = 30 days;
    uint256 public constant PREMIUM_DURATION = 90 days;
    uint256 public constant VIP_DURATION = 365 days;

    uint256 public constant MAX_REFERRAL_BONUS = 10;
    uint256 public constant RENEWAL_DISCOUNT = 5;


    enum MembershipTier { None, Basic, Premium, VIP }
    enum MembershipStatus { Inactive, Active, Expired }


    struct Member {
        MembershipTier tier;
        MembershipStatus status;
        uint256 startTime;
        uint256 endTime;
        uint256 totalSpent;
        address referrer;
        uint256 referralCount;
        bool hasRenewed;
    }

    struct TierConfig {
        uint256 price;
        uint256 duration;
        uint256 maxBenefits;
        bool isActive;
    }


    mapping(address => Member) private members;
    mapping(MembershipTier => TierConfig) private tierConfigs;
    mapping(address => uint256) private referralEarnings;

    address[] private memberList;
    uint256 private totalMembers;
    uint256 private totalRevenue;


    event MembershipPurchased(
        address indexed member,
        MembershipTier tier,
        uint256 price,
        uint256 duration,
        address referrer
    );

    event MembershipRenewed(
        address indexed member,
        MembershipTier tier,
        uint256 price,
        uint256 newEndTime
    );

    event MembershipExpired(address indexed member, MembershipTier tier);

    event ReferralBonusPaid(
        address indexed referrer,
        address indexed referee,
        uint256 bonus
    );

    event TierConfigUpdated(
        MembershipTier tier,
        uint256 price,
        uint256 duration,
        uint256 maxBenefits
    );


    modifier validTier(MembershipTier _tier) {
        require(_tier != MembershipTier.None, "Invalid membership tier");
        require(tierConfigs[_tier].isActive, "Tier is not active");
        _;
    }

    modifier onlyActiveMember() {
        require(isActiveMember(msg.sender), "Not an active member");
        _;
    }

    modifier notExpiredMember() {
        Member storage member = members[msg.sender];
        require(
            member.status == MembershipStatus.Active &&
            block.timestamp <= member.endTime,
            "Membership expired"
        );
        _;
    }

    constructor() {
        _initializeTierConfigs();
    }


    function _initializeTierConfigs() internal {
        tierConfigs[MembershipTier.Basic] = TierConfig({
            price: BASIC_TIER_PRICE,
            duration: BASIC_DURATION,
            maxBenefits: 5,
            isActive: true
        });

        tierConfigs[MembershipTier.Premium] = TierConfig({
            price: PREMIUM_TIER_PRICE,
            duration: PREMIUM_DURATION,
            maxBenefits: 15,
            isActive: true
        });

        tierConfigs[MembershipTier.VIP] = TierConfig({
            price: VIP_TIER_PRICE,
            duration: VIP_DURATION,
            maxBenefits: 50,
            isActive: true
        });
    }

    function _calculatePrice(MembershipTier _tier, bool _isRenewal) internal view returns (uint256) {
        uint256 basePrice = tierConfigs[_tier].price;

        if (_isRenewal) {
            return basePrice.sub(basePrice.mul(RENEWAL_DISCOUNT).div(100));
        }

        return basePrice;
    }

    function _processReferralBonus(address _referrer, uint256 _amount) internal {
        if (_referrer != address(0) && _referrer != msg.sender) {
            uint256 bonus = _amount.mul(MAX_REFERRAL_BONUS).div(100);
            referralEarnings[_referrer] = referralEarnings[_referrer].add(bonus);

            emit ReferralBonusPaid(_referrer, msg.sender, bonus);
        }
    }

    function _updateMembershipStatus(address _member) internal {
        Member storage member = members[_member];

        if (member.status == MembershipStatus.Active && block.timestamp > member.endTime) {
            member.status = MembershipStatus.Expired;
            emit MembershipExpired(_member, member.tier);
        }
    }

    function _addNewMember(address _member) internal {
        bool isNewMember = members[_member].tier == MembershipTier.None;

        if (isNewMember) {
            memberList.push(_member);
            totalMembers = totalMembers.add(1);
        }
    }


    function purchaseMembership(
        MembershipTier _tier,
        address _referrer
    ) external payable validTier(_tier) whenNotPaused nonReentrant {
        require(_tier != MembershipTier.None, "Cannot purchase None tier");

        Member storage member = members[msg.sender];
        bool isRenewal = member.tier == _tier && member.status != MembershipStatus.Inactive;

        uint256 price = _calculatePrice(_tier, isRenewal);
        require(msg.value >= price, "Insufficient payment");


        if (_referrer != address(0)) {
            require(_referrer != msg.sender, "Cannot refer yourself");
            require(isActiveMember(_referrer), "Referrer must be active member");
        }

        _addNewMember(msg.sender);


        uint256 startTime = block.timestamp;
        uint256 duration = tierConfigs[_tier].duration;

        if (isRenewal && member.status == MembershipStatus.Active) {

            member.endTime = member.endTime.add(duration);
            member.hasRenewed = true;

            emit MembershipRenewed(msg.sender, _tier, price, member.endTime);
        } else {

            member.tier = _tier;
            member.status = MembershipStatus.Active;
            member.startTime = startTime;
            member.endTime = startTime.add(duration);

            if (member.referrer == address(0) && _referrer != address(0)) {
                member.referrer = _referrer;
                members[_referrer].referralCount = members[_referrer].referralCount.add(1);
            }

            emit MembershipPurchased(msg.sender, _tier, price, duration, _referrer);
        }

        member.totalSpent = member.totalSpent.add(price);
        totalRevenue = totalRevenue.add(price);


        if (member.referrer != address(0)) {
            _processReferralBonus(member.referrer, price);
        }


        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value.sub(price));
        }
    }

    function renewMembership() external payable onlyActiveMember whenNotPaused nonReentrant {
        Member storage member = members[msg.sender];
        MembershipTier currentTier = member.tier;

        uint256 price = _calculatePrice(currentTier, true);
        require(msg.value >= price, "Insufficient payment for renewal");

        uint256 duration = tierConfigs[currentTier].duration;
        member.endTime = member.endTime.add(duration);
        member.totalSpent = member.totalSpent.add(price);
        member.hasRenewed = true;

        totalRevenue = totalRevenue.add(price);


        if (member.referrer != address(0)) {
            _processReferralBonus(member.referrer, price);
        }

        emit MembershipRenewed(msg.sender, currentTier, price, member.endTime);


        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value.sub(price));
        }
    }

    function claimReferralEarnings() external nonReentrant {
        uint256 earnings = referralEarnings[msg.sender];
        require(earnings > 0, "No earnings to claim");
        require(address(this).balance >= earnings, "Insufficient contract balance");

        referralEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
    }


    function getMemberInfo(address _member) external view returns (
        MembershipTier tier,
        MembershipStatus status,
        uint256 startTime,
        uint256 endTime,
        uint256 totalSpent,
        address referrer,
        uint256 referralCount,
        bool hasRenewed
    ) {
        Member storage member = members[_member];
        return (
            member.tier,
            member.status,
            member.startTime,
            member.endTime,
            member.totalSpent,
            member.referrer,
            member.referralCount,
            member.hasRenewed
        );
    }

    function isActiveMember(address _member) public view returns (bool) {
        Member storage member = members[_member];
        return member.status == MembershipStatus.Active &&
               block.timestamp <= member.endTime;
    }

    function getMembershipPrice(MembershipTier _tier, bool _isRenewal) external view returns (uint256) {
        return _calculatePrice(_tier, _isRenewal);
    }

    function getTierConfig(MembershipTier _tier) external view returns (TierConfig memory) {
        return tierConfigs[_tier];
    }

    function getReferralEarnings(address _member) external view returns (uint256) {
        return referralEarnings[_member];
    }

    function getContractStats() external view returns (
        uint256 _totalMembers,
        uint256 _totalRevenue,
        uint256 _contractBalance
    ) {
        return (totalMembers, totalRevenue, address(this).balance);
    }

    function getAllMembers() external view returns (address[] memory) {
        return memberList;
    }


    function updateTierConfig(
        MembershipTier _tier,
        uint256 _price,
        uint256 _duration,
        uint256 _maxBenefits,
        bool _isActive
    ) external onlyOwner {
        require(_tier != MembershipTier.None, "Cannot configure None tier");

        tierConfigs[_tier] = TierConfig({
            price: _price,
            duration: _duration,
            maxBenefits: _maxBenefits,
            isActive: _isActive
        });

        emit TierConfigUpdated(_tier, _price, _duration, _maxBenefits);
    }

    function forceExpireMembership(address _member) external onlyOwner {
        Member storage member = members[_member];
        require(member.status == MembershipStatus.Active, "Member not active");

        member.status = MembershipStatus.Expired;
        emit MembershipExpired(_member, member.tier);
    }

    function updateMembershipStatuses(address[] calldata _members) external onlyOwner {
        for (uint256 i = 0; i < _members.length; i++) {
            _updateMembershipStatus(_members[i]);
        }
    }

    function withdrawFunds(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(_amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }


    receive() external payable {

    }
}
