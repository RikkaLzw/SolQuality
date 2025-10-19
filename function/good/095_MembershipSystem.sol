
pragma solidity ^0.8.0;

contract MembershipSystem {

    enum MembershipTier { None, Bronze, Silver, Gold, Platinum }


    struct Member {
        bool isActive;
        MembershipTier tier;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
    }


    mapping(address => Member) private members;
    mapping(MembershipTier => uint256) private tierPrices;
    mapping(MembershipTier => uint256) private tierDurations;

    address private owner;
    uint256 private totalMembers;


    event MemberRegistered(address indexed member, MembershipTier tier);
    event MembershipRenewed(address indexed member, uint256 newExpiryDate);
    event MembershipUpgraded(address indexed member, MembershipTier newTier);
    event MembershipExpired(address indexed member);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveMember() {
        require(isActiveMember(msg.sender), "Membership required");
        _;
    }

    constructor() {
        owner = msg.sender;
        _initializeTierPrices();
        _initializeTierDurations();
    }


    function _initializeTierPrices() private {
        tierPrices[MembershipTier.Bronze] = 0.01 ether;
        tierPrices[MembershipTier.Silver] = 0.05 ether;
        tierPrices[MembershipTier.Gold] = 0.1 ether;
        tierPrices[MembershipTier.Platinum] = 0.2 ether;
    }


    function _initializeTierDurations() private {
        tierDurations[MembershipTier.Bronze] = 30 days;
        tierDurations[MembershipTier.Silver] = 90 days;
        tierDurations[MembershipTier.Gold] = 180 days;
        tierDurations[MembershipTier.Platinum] = 365 days;
    }


    function registerMembership(MembershipTier tier) external payable {
        require(tier != MembershipTier.None, "Invalid tier");
        require(msg.value >= tierPrices[tier], "Insufficient payment");
        require(!members[msg.sender].isActive, "Already a member");

        uint256 expiryDate = block.timestamp + tierDurations[tier];

        members[msg.sender] = Member({
            isActive: true,
            tier: tier,
            joinDate: block.timestamp,
            expiryDate: expiryDate,
            totalSpent: msg.value
        });

        totalMembers++;
        emit MemberRegistered(msg.sender, tier);
    }


    function renewMembership() external payable onlyActiveMember {
        Member storage member = members[msg.sender];
        require(msg.value >= tierPrices[member.tier], "Insufficient payment");

        member.expiryDate += tierDurations[member.tier];
        member.totalSpent += msg.value;

        emit MembershipRenewed(msg.sender, member.expiryDate);
    }


    function upgradeMembership(MembershipTier newTier) external payable onlyActiveMember {
        Member storage member = members[msg.sender];
        require(newTier > member.tier, "Invalid upgrade");
        require(msg.value >= tierPrices[newTier], "Insufficient payment");

        member.tier = newTier;
        member.expiryDate = block.timestamp + tierDurations[newTier];
        member.totalSpent += msg.value;

        emit MembershipUpgraded(msg.sender, newTier);
    }


    function isActiveMember(address memberAddress) public view returns (bool) {
        Member memory member = members[memberAddress];
        return member.isActive && block.timestamp <= member.expiryDate;
    }


    function getMemberInfo(address memberAddress) external view returns (Member memory) {
        return members[memberAddress];
    }


    function getTierPrice(MembershipTier tier) external view returns (uint256) {
        return tierPrices[tier];
    }


    function getTierDuration(MembershipTier tier) external view returns (uint256) {
        return tierDurations[tier];
    }


    function getTotalMembers() external view returns (uint256) {
        return totalMembers;
    }


    function setTierPrice(MembershipTier tier, uint256 price) external onlyOwner {
        require(tier != MembershipTier.None, "Invalid tier");
        tierPrices[tier] = price;
    }


    function setTierDuration(MembershipTier tier, uint256 duration) external onlyOwner {
        require(tier != MembershipTier.None, "Invalid tier");
        tierDurations[tier] = duration;
    }


    function revokeMembership(address memberAddress) external onlyOwner {
        require(members[memberAddress].isActive, "Member not active");
        members[memberAddress].isActive = false;
        emit MembershipExpired(memberAddress);
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
