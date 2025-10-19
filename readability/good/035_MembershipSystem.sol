
pragma solidity ^0.8.0;


contract MembershipSystem {


    enum MembershipTier {
        None,
        Bronze,
        Silver,
        Gold,
        Platinum
    }


    struct MemberInfo {
        MembershipTier tier;
        uint256 expirationTime;
        uint256 totalSpent;
        uint256 joinTime;
        bool isActive;
    }


    struct TierConfig {
        uint256 price;
        uint256 duration;
        uint256 discountRate;
        uint256 minSpentRequired;
        bool isAvailable;
    }


    address public owner;
    mapping(address => MemberInfo) public members;
    mapping(MembershipTier => TierConfig) public tierConfigs;

    uint256 public totalMembers;
    uint256 public constant BASIS_POINTS = 10000;


    event MembershipPurchased(
        address indexed member,
        MembershipTier tier,
        uint256 expirationTime,
        uint256 price
    );

    event MembershipUpgraded(
        address indexed member,
        MembershipTier fromTier,
        MembershipTier toTier
    );

    event MembershipExpired(
        address indexed member,
        MembershipTier tier
    );

    event TierConfigUpdated(
        MembershipTier tier,
        uint256 price,
        uint256 duration,
        uint256 discountRate
    );

    event SpendingRecorded(
        address indexed member,
        uint256 amount,
        uint256 totalSpent
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validTier(MembershipTier _tier) {
        require(_tier != MembershipTier.None, "Invalid membership tier");
        require(tierConfigs[_tier].isAvailable, "Tier not available");
        _;
    }

    modifier activeMember() {
        require(members[msg.sender].isActive, "Not an active member");
        require(block.timestamp < members[msg.sender].expirationTime, "Membership expired");
        _;
    }


    constructor() {
        owner = msg.sender;


        _initializeTierConfigs();
    }


    function _initializeTierConfigs() private {

        tierConfigs[MembershipTier.Bronze] = TierConfig({
            price: 0.01 ether,
            duration: 30 days,
            discountRate: 500,
            minSpentRequired: 0,
            isAvailable: true
        });


        tierConfigs[MembershipTier.Silver] = TierConfig({
            price: 0.05 ether,
            duration: 90 days,
            discountRate: 1000,
            minSpentRequired: 0.1 ether,
            isAvailable: true
        });


        tierConfigs[MembershipTier.Gold] = TierConfig({
            price: 0.1 ether,
            duration: 180 days,
            discountRate: 1500,
            minSpentRequired: 0.5 ether,
            isAvailable: true
        });


        tierConfigs[MembershipTier.Platinum] = TierConfig({
            price: 0.2 ether,
            duration: 365 days,
            discountRate: 2000,
            minSpentRequired: 1 ether,
            isAvailable: true
        });
    }


    function purchaseMembership(MembershipTier _tier)
        external
        payable
        validTier(_tier)
    {
        TierConfig memory config = tierConfigs[_tier];
        require(msg.value >= config.price, "Insufficient payment");

        MemberInfo storage member = members[msg.sender];


        require(
            member.totalSpent >= config.minSpentRequired,
            "Insufficient spending for this tier"
        );


        if (!member.isActive) {
            totalMembers++;
            member.joinTime = block.timestamp;
        }


        MembershipTier previousTier = member.tier;
        member.tier = _tier;
        member.expirationTime = block.timestamp + config.duration;
        member.isActive = true;


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }


        if (previousTier == MembershipTier.None) {
            emit MembershipPurchased(msg.sender, _tier, member.expirationTime, config.price);
        } else {
            emit MembershipUpgraded(msg.sender, previousTier, _tier);
        }
    }


    function renewMembership() external payable activeMember {
        MemberInfo storage member = members[msg.sender];
        TierConfig memory config = tierConfigs[member.tier];

        require(msg.value >= config.price, "Insufficient payment");


        if (block.timestamp < member.expirationTime) {
            member.expirationTime += config.duration;
        } else {
            member.expirationTime = block.timestamp + config.duration;
        }


        if (msg.value > config.price) {
            payable(msg.sender).transfer(msg.value - config.price);
        }

        emit MembershipPurchased(msg.sender, member.tier, member.expirationTime, config.price);
    }


    function recordSpending(address _member, uint256 _amount) external onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(_amount > 0, "Amount must be greater than 0");

        MemberInfo storage member = members[_member];
        member.totalSpent += _amount;

        emit SpendingRecorded(_member, _amount, member.totalSpent);


        _checkAutoUpgrade(_member);
    }


    function _checkAutoUpgrade(address _member) private {
        MemberInfo storage member = members[_member];

        if (!member.isActive || block.timestamp >= member.expirationTime) {
            return;
        }

        MembershipTier currentTier = member.tier;
        MembershipTier newTier = _getEligibleTier(member.totalSpent);

        if (newTier > currentTier) {
            MembershipTier previousTier = member.tier;
            member.tier = newTier;
            emit MembershipUpgraded(_member, previousTier, newTier);
        }
    }


    function _getEligibleTier(uint256 _totalSpent) private view returns (MembershipTier) {
        if (_totalSpent >= tierConfigs[MembershipTier.Platinum].minSpentRequired) {
            return MembershipTier.Platinum;
        } else if (_totalSpent >= tierConfigs[MembershipTier.Gold].minSpentRequired) {
            return MembershipTier.Gold;
        } else if (_totalSpent >= tierConfigs[MembershipTier.Silver].minSpentRequired) {
            return MembershipTier.Silver;
        } else {
            return MembershipTier.Bronze;
        }
    }


    function getMemberDiscount(address _member) external view returns (uint256) {
        MemberInfo memory member = members[_member];

        if (!member.isActive || block.timestamp >= member.expirationTime) {
            return 0;
        }

        return tierConfigs[member.tier].discountRate;
    }


    function calculateDiscountedPrice(address _member, uint256 _originalPrice)
        external
        view
        returns (uint256)
    {
        uint256 discountRate = this.getMemberDiscount(_member);

        if (discountRate == 0) {
            return _originalPrice;
        }

        uint256 discountAmount = (_originalPrice * discountRate) / BASIS_POINTS;
        return _originalPrice - discountAmount;
    }


    function isValidMember(address _member) external view returns (bool) {
        MemberInfo memory member = members[_member];
        return member.isActive && block.timestamp < member.expirationTime;
    }


    function getMemberInfo(address _member)
        external
        view
        returns (
            MembershipTier tier,
            uint256 expirationTime,
            uint256 totalSpent,
            uint256 joinTime,
            bool isActive
        )
    {
        MemberInfo memory member = members[_member];
        return (
            member.tier,
            member.expirationTime,
            member.totalSpent,
            member.joinTime,
            member.isActive
        );
    }


    function updateTierConfig(
        MembershipTier _tier,
        uint256 _price,
        uint256 _duration,
        uint256 _discountRate,
        uint256 _minSpentRequired
    ) external onlyOwner {
        require(_tier != MembershipTier.None, "Cannot update None tier");
        require(_discountRate <= BASIS_POINTS, "Discount rate too high");
        require(_duration > 0, "Duration must be greater than 0");

        tierConfigs[_tier] = TierConfig({
            price: _price,
            duration: _duration,
            discountRate: _discountRate,
            minSpentRequired: _minSpentRequired,
            isAvailable: true
        });

        emit TierConfigUpdated(_tier, _price, _duration, _discountRate);
    }


    function setTierAvailability(MembershipTier _tier, bool _isAvailable)
        external
        onlyOwner
    {
        require(_tier != MembershipTier.None, "Cannot modify None tier");
        tierConfigs[_tier].isAvailable = _isAvailable;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner).transfer(balance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different");

        owner = _newOwner;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function batchCheckExpiration(address[] calldata _members)
        external
        view
        returns (bool[] memory)
    {
        bool[] memory results = new bool[](_members.length);

        for (uint256 i = 0; i < _members.length; i++) {
            MemberInfo memory member = members[_members[i]];
            results[i] = member.isActive && block.timestamp >= member.expirationTime;
        }

        return results;
    }
}
