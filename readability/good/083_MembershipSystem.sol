
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
        uint256 joinTimestamp;
        uint256 expirationTimestamp;
        uint256 totalSpent;
        bool isActive;
    }


    address public owner;
    mapping(address => MemberInfo) public members;
    mapping(MembershipTier => uint256) public tierPrices;
    mapping(MembershipTier => uint256) public tierDurations;
    uint256 public totalMembers;


    event MembershipPurchased(
        address indexed member,
        MembershipTier tier,
        uint256 price,
        uint256 expirationTime
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

    event TierPriceUpdated(
        MembershipTier tier,
        uint256 oldPrice,
        uint256 newPrice
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validTier(MembershipTier _tier) {
        require(_tier != MembershipTier.None, "Invalid membership tier");
        require(_tier <= MembershipTier.Platinum, "Tier does not exist");
        _;
    }


    constructor() {
        owner = msg.sender;


        tierPrices[MembershipTier.Bronze] = 0.01 ether;
        tierPrices[MembershipTier.Silver] = 0.05 ether;
        tierPrices[MembershipTier.Gold] = 0.1 ether;
        tierPrices[MembershipTier.Platinum] = 0.2 ether;


        tierDurations[MembershipTier.Bronze] = 30 days;
        tierDurations[MembershipTier.Silver] = 90 days;
        tierDurations[MembershipTier.Gold] = 180 days;
        tierDurations[MembershipTier.Platinum] = 365 days;
    }


    function purchaseMembership(MembershipTier _tier)
        external
        payable
        validTier(_tier)
    {
        require(msg.value >= tierPrices[_tier], "Insufficient payment");

        MemberInfo storage member = members[msg.sender];


        if (member.tier == MembershipTier.None) {
            totalMembers++;
        }


        MembershipTier oldTier = member.tier;


        member.tier = _tier;
        member.joinTimestamp = block.timestamp;
        member.expirationTimestamp = block.timestamp + tierDurations[_tier];
        member.totalSpent += msg.value;
        member.isActive = true;


        if (msg.value > tierPrices[_tier]) {
            payable(msg.sender).transfer(msg.value - tierPrices[_tier]);
        }


        if (oldTier == MembershipTier.None) {
            emit MembershipPurchased(
                msg.sender,
                _tier,
                tierPrices[_tier],
                member.expirationTimestamp
            );
        } else {
            emit MembershipUpgraded(msg.sender, oldTier, _tier);
        }
    }


    function renewMembership() external payable {
        MemberInfo storage member = members[msg.sender];
        require(member.tier != MembershipTier.None, "No existing membership");
        require(msg.value >= tierPrices[member.tier], "Insufficient payment");


        uint256 startTime = member.expirationTimestamp > block.timestamp
            ? member.expirationTimestamp
            : block.timestamp;

        member.expirationTimestamp = startTime + tierDurations[member.tier];
        member.totalSpent += msg.value;
        member.isActive = true;


        if (msg.value > tierPrices[member.tier]) {
            payable(msg.sender).transfer(msg.value - tierPrices[member.tier]);
        }

        emit MembershipPurchased(
            msg.sender,
            member.tier,
            tierPrices[member.tier],
            member.expirationTimestamp
        );
    }


    function isActiveMember(address _member) external view returns (bool) {
        MemberInfo storage member = members[_member];
        return member.isActive &&
               member.tier != MembershipTier.None &&
               block.timestamp <= member.expirationTimestamp;
    }


    function getMemberInfo(address _member)
        external
        view
        returns (
            MembershipTier tier,
            uint256 joinTimestamp,
            uint256 expirationTimestamp,
            uint256 totalSpent,
            bool isActive
        )
    {
        MemberInfo storage member = members[_member];
        return (
            member.tier,
            member.joinTimestamp,
            member.expirationTimestamp,
            member.totalSpent,
            member.isActive && block.timestamp <= member.expirationTimestamp
        );
    }


    function getTierPrice(MembershipTier _tier)
        external
        view
        validTier(_tier)
        returns (uint256)
    {
        return tierPrices[_tier];
    }


    function getTierDuration(MembershipTier _tier)
        external
        view
        validTier(_tier)
        returns (uint256)
    {
        return tierDurations[_tier];
    }


    function updateTierPrice(MembershipTier _tier, uint256 _newPrice)
        external
        onlyOwner
        validTier(_tier)
    {
        require(_newPrice > 0, "Price must be greater than zero");

        uint256 oldPrice = tierPrices[_tier];
        tierPrices[_tier] = _newPrice;

        emit TierPriceUpdated(_tier, oldPrice, _newPrice);
    }


    function updateTierDuration(MembershipTier _tier, uint256 _newDuration)
        external
        onlyOwner
        validTier(_tier)
    {
        require(_newDuration > 0, "Duration must be greater than zero");
        tierDurations[_tier] = _newDuration;
    }


    function setMemberStatus(address _member, bool _isActive)
        external
        onlyOwner
    {
        members[_member].isActive = _isActive;

        if (!_isActive) {
            emit MembershipExpired(_member, members[_member].tier);
        }
    }


    function withdrawFunds() external onlyOwner {
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


    function batchCheckMemberStatus(address[] calldata _members)
        external
        view
        returns (bool[] memory)
    {
        bool[] memory statuses = new bool[](_members.length);

        for (uint256 i = 0; i < _members.length; i++) {
            MemberInfo storage member = members[_members[i]];
            statuses[i] = member.isActive &&
                         member.tier != MembershipTier.None &&
                         block.timestamp <= member.expirationTimestamp;
        }

        return statuses;
    }
}
