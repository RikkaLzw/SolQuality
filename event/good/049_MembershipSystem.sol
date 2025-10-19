
pragma solidity ^0.8.0;

contract MembershipSystem {

    enum MembershipTier { None, Bronze, Silver, Gold, Platinum }


    struct Member {
        bool isActive;
        MembershipTier tier;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
        string email;
    }


    mapping(address => Member) public members;
    mapping(MembershipTier => uint256) public tierPrices;
    mapping(MembershipTier => uint256) public tierDurations;

    address public owner;
    uint256 public totalMembers;
    uint256 public totalRevenue;


    event MemberRegistered(
        address indexed memberAddress,
        string indexed email,
        MembershipTier indexed tier,
        uint256 joinDate,
        uint256 expiryDate
    );

    event MembershipUpgraded(
        address indexed memberAddress,
        MembershipTier indexed oldTier,
        MembershipTier indexed newTier,
        uint256 newExpiryDate
    );

    event MembershipRenewed(
        address indexed memberAddress,
        MembershipTier indexed tier,
        uint256 newExpiryDate,
        uint256 amount
    );

    event MembershipExpired(
        address indexed memberAddress,
        MembershipTier indexed tier
    );

    event TierPriceUpdated(
        MembershipTier indexed tier,
        uint256 oldPrice,
        uint256 newPrice
    );

    event RevenueWithdrawn(
        address indexed owner,
        uint256 amount
    );


    error NotOwner();
    error InvalidTier();
    error InsufficientPayment();
    error MemberAlreadyExists();
    error MemberNotFound();
    error MembershipExpired();
    error InvalidEmail();
    error InvalidDuration();
    error WithdrawalFailed();


    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier validTier(MembershipTier _tier) {
        if (_tier == MembershipTier.None || _tier > MembershipTier.Platinum) {
            revert InvalidTier();
        }
        _;
    }

    modifier memberExists(address _member) {
        if (!members[_member].isActive) revert MemberNotFound();
        _;
    }

    modifier validEmail(string memory _email) {
        if (bytes(_email).length == 0) revert InvalidEmail();
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


    function registerMember(
        MembershipTier _tier,
        string memory _email
    ) external payable validTier(_tier) validEmail(_email) {
        if (members[msg.sender].isActive) revert MemberAlreadyExists();
        if (msg.value < tierPrices[_tier]) revert InsufficientPayment();

        uint256 expiryDate = block.timestamp + tierDurations[_tier];

        members[msg.sender] = Member({
            isActive: true,
            tier: _tier,
            joinDate: block.timestamp,
            expiryDate: expiryDate,
            totalSpent: msg.value,
            email: _email
        });

        totalMembers++;
        totalRevenue += msg.value;

        emit MemberRegistered(
            msg.sender,
            _email,
            _tier,
            block.timestamp,
            expiryDate
        );
    }


    function upgradeMembership(
        MembershipTier _newTier
    ) external payable memberExists(msg.sender) validTier(_newTier) {
        Member storage member = members[msg.sender];

        if (block.timestamp > member.expiryDate) revert MembershipExpired();
        if (_newTier <= member.tier) revert InvalidTier();

        uint256 upgradeCost = tierPrices[_newTier] - tierPrices[member.tier];
        if (msg.value < upgradeCost) revert InsufficientPayment();

        MembershipTier oldTier = member.tier;
        member.tier = _newTier;
        member.totalSpent += msg.value;


        uint256 remainingTime = member.expiryDate - block.timestamp;
        member.expiryDate = block.timestamp + tierDurations[_newTier] + remainingTime;

        totalRevenue += msg.value;

        emit MembershipUpgraded(
            msg.sender,
            oldTier,
            _newTier,
            member.expiryDate
        );
    }


    function renewMembership() external payable memberExists(msg.sender) {
        Member storage member = members[msg.sender];

        if (msg.value < tierPrices[member.tier]) revert InsufficientPayment();


        uint256 baseTime = block.timestamp > member.expiryDate ?
            block.timestamp : member.expiryDate;

        member.expiryDate = baseTime + tierDurations[member.tier];
        member.totalSpent += msg.value;

        totalRevenue += msg.value;

        emit MembershipRenewed(
            msg.sender,
            member.tier,
            member.expiryDate,
            msg.value
        );
    }


    function isMembershipActive(address _member) external view returns (bool) {
        Member memory member = members[_member];
        return member.isActive && block.timestamp <= member.expiryDate;
    }


    function getMemberDetails(address _member) external view returns (
        bool isActive,
        MembershipTier tier,
        uint256 joinDate,
        uint256 expiryDate,
        uint256 totalSpent,
        string memory email
    ) {
        Member memory member = members[_member];
        return (
            member.isActive,
            member.tier,
            member.joinDate,
            member.expiryDate,
            member.totalSpent,
            member.email
        );
    }


    function updateTierPrice(
        MembershipTier _tier,
        uint256 _newPrice
    ) external onlyOwner validTier(_tier) {
        require(_newPrice > 0, "Price must be greater than zero");

        uint256 oldPrice = tierPrices[_tier];
        tierPrices[_tier] = _newPrice;

        emit TierPriceUpdated(_tier, oldPrice, _newPrice);
    }

    function updateTierDuration(
        MembershipTier _tier,
        uint256 _newDuration
    ) external onlyOwner validTier(_tier) {
        if (_newDuration == 0) revert InvalidDuration();

        tierDurations[_tier] = _newDuration;
    }


    function expireMembership(address _member) external onlyOwner memberExists(_member) {
        Member storage member = members[_member];
        member.expiryDate = block.timestamp;

        emit MembershipExpired(_member, member.tier);
    }


    function withdrawRevenue() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner).call{value: balance}("");
        if (!success) revert WithdrawalFailed();

        emit RevenueWithdrawn(owner, balance);
    }


    function getContractStats() external view returns (
        uint256 _totalMembers,
        uint256 _totalRevenue,
        uint256 _contractBalance
    ) {
        return (totalMembers, totalRevenue, address(this).balance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
