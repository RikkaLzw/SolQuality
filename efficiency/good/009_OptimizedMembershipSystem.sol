
pragma solidity ^0.8.19;

contract OptimizedMembershipSystem {

    struct Member {
        uint128 joinTimestamp;
        uint64 tierLevel;
        uint32 pointsBalance;
        uint32 totalSpent;
        bool isActive;
    }


    struct MembershipTier {
        uint32 requiredPoints;
        uint16 discountPercentage;
        uint16 bonusMultiplier;
        bool exists;
    }


    event MemberRegistered(address indexed member, uint256 timestamp);
    event MemberUpgraded(address indexed member, uint64 newTier);
    event PointsEarned(address indexed member, uint32 points);
    event PointsRedeemed(address indexed member, uint32 points);
    event TierCreated(uint64 indexed tierId, uint32 requiredPoints);


    address public immutable owner;
    uint256 public totalMembers;
    uint64 public nextTierId = 1;


    mapping(address => Member) public members;
    mapping(uint64 => MembershipTier) public tiers;
    mapping(address => bool) public authorized;


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveMember(address memberAddr) {
        require(members[memberAddr].isActive, "Member not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;


        _createTier(0, 0, 100);
        _createTier(1000, 500, 150);
        _createTier(5000, 1000, 200);
        _createTier(15000, 1500, 300);
    }

    function registerMember(address memberAddr) external onlyAuthorized {
        require(memberAddr != address(0), "Invalid address");
        require(!members[memberAddr].isActive, "Already registered");

        members[memberAddr] = Member({
            joinTimestamp: uint128(block.timestamp),
            tierLevel: 1,
            pointsBalance: 0,
            totalSpent: 0,
            isActive: true
        });

        unchecked {
            totalMembers++;
        }

        emit MemberRegistered(memberAddr, block.timestamp);
    }

    function addPoints(address memberAddr, uint32 points)
        external
        onlyAuthorized
        onlyActiveMember(memberAddr)
    {
        Member storage member = members[memberAddr];


        MembershipTier memory currentTier = tiers[member.tierLevel];


        uint32 bonusPoints = (points * currentTier.bonusMultiplier) / 100;
        uint32 totalPoints = points + bonusPoints;


        member.pointsBalance += totalPoints;


        uint64 newTierLevel = _calculateTierLevel(member.pointsBalance);
        if (newTierLevel > member.tierLevel) {
            member.tierLevel = newTierLevel;
            emit MemberUpgraded(memberAddr, newTierLevel);
        }

        emit PointsEarned(memberAddr, totalPoints);
    }

    function redeemPoints(address memberAddr, uint32 points)
        external
        onlyAuthorized
        onlyActiveMember(memberAddr)
    {
        Member storage member = members[memberAddr];
        require(member.pointsBalance >= points, "Insufficient points");

        unchecked {
            member.pointsBalance -= points;
        }

        emit PointsRedeemed(memberAddr, points);
    }

    function recordPurchase(address memberAddr, uint32 amount)
        external
        onlyAuthorized
        onlyActiveMember(memberAddr)
    {
        Member storage member = members[memberAddr];
        member.totalSpent += amount;


        this.addPoints(memberAddr, amount);
    }

    function getMemberInfo(address memberAddr)
        external
        view
        returns (
            uint128 joinTimestamp,
            uint64 tierLevel,
            uint32 pointsBalance,
            uint32 totalSpent,
            bool isActive,
            uint16 discountPercentage
        )
    {
        Member memory member = members[memberAddr];
        MembershipTier memory tier = tiers[member.tierLevel];

        return (
            member.joinTimestamp,
            member.tierLevel,
            member.pointsBalance,
            member.totalSpent,
            member.isActive,
            tier.discountPercentage
        );
    }

    function calculateDiscount(address memberAddr, uint256 purchaseAmount)
        external
        view
        onlyActiveMember(memberAddr)
        returns (uint256 discountAmount)
    {
        Member memory member = members[memberAddr];
        MembershipTier memory tier = tiers[member.tierLevel];

        discountAmount = (purchaseAmount * tier.discountPercentage) / 10000;
    }

    function createTier(uint32 requiredPoints, uint16 discountPercentage, uint16 bonusMultiplier)
        external
        onlyOwner
        returns (uint64 tierId)
    {
        tierId = _createTier(requiredPoints, discountPercentage, bonusMultiplier);
    }

    function deactivateMember(address memberAddr) external onlyOwner {
        require(members[memberAddr].isActive, "Member not active");
        members[memberAddr].isActive = false;

        unchecked {
            totalMembers--;
        }
    }

    function setAuthorized(address addr, bool status) external onlyOwner {
        authorized[addr] = status;
    }

    function _createTier(uint32 requiredPoints, uint16 discountPercentage, uint16 bonusMultiplier)
        internal
        returns (uint64 tierId)
    {
        require(discountPercentage <= 5000, "Discount too high");
        require(bonusMultiplier >= 100, "Invalid multiplier");

        tierId = nextTierId;
        tiers[tierId] = MembershipTier({
            requiredPoints: requiredPoints,
            discountPercentage: discountPercentage,
            bonusMultiplier: bonusMultiplier,
            exists: true
        });

        unchecked {
            nextTierId++;
        }

        emit TierCreated(tierId, requiredPoints);
    }

    function _calculateTierLevel(uint32 points) internal view returns (uint64) {
        uint64 bestTier = 1;


        for (uint64 i = 2; i < nextTierId; i++) {
            MembershipTier memory tier = tiers[i];
            if (tier.exists && points >= tier.requiredPoints) {
                bestTier = i;
            } else {
                break;
            }
        }

        return bestTier;
    }

    function getTierInfo(uint64 tierId)
        external
        view
        returns (
            uint32 requiredPoints,
            uint16 discountPercentage,
            uint16 bonusMultiplier,
            bool exists
        )
    {
        MembershipTier memory tier = tiers[tierId];
        return (
            tier.requiredPoints,
            tier.discountPercentage,
            tier.bonusMultiplier,
            tier.exists
        );
    }

    function isMemberActive(address memberAddr) external view returns (bool) {
        return members[memberAddr].isActive;
    }
}
