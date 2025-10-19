
pragma solidity ^0.8.0;

contract MembershipSystem {

    enum MembershipTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM
    }


    struct Member {
        bytes32 memberId;
        address memberAddress;
        MembershipTier tier;
        uint32 joinTimestamp;
        uint32 expiryTimestamp;
        uint16 loyaltyPoints;
        bool isActive;
        bytes32 referralCode;
    }


    address public owner;
    uint32 public totalMembers;
    mapping(address => Member) public members;
    mapping(bytes32 => address) public memberIdToAddress;
    mapping(bytes32 => address) public referralCodeToAddress;


    mapping(MembershipTier => uint256) public tierFees;


    event MemberRegistered(address indexed member, bytes32 memberId, MembershipTier tier);
    event MembershipUpgraded(address indexed member, MembershipTier newTier);
    event MembershipRenewed(address indexed member, uint32 newExpiryTimestamp);
    event LoyaltyPointsUpdated(address indexed member, uint16 newPoints);
    event MemberDeactivated(address indexed member);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Member is not active");
        require(members[msg.sender].expiryTimestamp > block.timestamp, "Membership expired");
        _;
    }

    modifier validTier(MembershipTier _tier) {
        require(_tier <= MembershipTier.PLATINUM, "Invalid membership tier");
        _;
    }

    constructor() {
        owner = msg.sender;


        tierFees[MembershipTier.BRONZE] = 0.01 ether;
        tierFees[MembershipTier.SILVER] = 0.05 ether;
        tierFees[MembershipTier.GOLD] = 0.1 ether;
        tierFees[MembershipTier.PLATINUM] = 0.2 ether;
    }


    function registerMember(
        MembershipTier _tier,
        bytes32 _referralCode
    ) external payable validTier(_tier) {
        require(!members[msg.sender].isActive, "Member already registered");
        require(msg.value >= tierFees[_tier], "Insufficient payment");

        bytes32 memberId = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalMembers));
        bytes32 newReferralCode = keccak256(abi.encodePacked(memberId, "REFERRAL"));


        if (_referralCode != bytes32(0)) {
            address referrer = referralCodeToAddress[_referralCode];
            require(referrer != address(0), "Invalid referral code");
            require(members[referrer].isActive, "Referrer is not active");


            _addLoyaltyPoints(referrer, 100);
        }

        uint32 currentTime = uint32(block.timestamp);
        uint32 expiryTime = currentTime + 365 days;

        members[msg.sender] = Member({
            memberId: memberId,
            memberAddress: msg.sender,
            tier: _tier,
            joinTimestamp: currentTime,
            expiryTimestamp: expiryTime,
            loyaltyPoints: 0,
            isActive: true,
            referralCode: newReferralCode
        });

        memberIdToAddress[memberId] = msg.sender;
        referralCodeToAddress[newReferralCode] = msg.sender;
        totalMembers++;


        if (msg.value > tierFees[_tier]) {
            payable(msg.sender).transfer(msg.value - tierFees[_tier]);
        }

        emit MemberRegistered(msg.sender, memberId, _tier);
    }


    function upgradeMembership(MembershipTier _newTier) external payable onlyActiveMember validTier(_newTier) {
        Member storage member = members[msg.sender];
        require(_newTier > member.tier, "Can only upgrade to higher tier");

        uint256 upgradeFee = tierFees[_newTier] - tierFees[member.tier];
        require(msg.value >= upgradeFee, "Insufficient payment for upgrade");

        member.tier = _newTier;


        if (msg.value > upgradeFee) {
            payable(msg.sender).transfer(msg.value - upgradeFee);
        }

        emit MembershipUpgraded(msg.sender, _newTier);
    }


    function renewMembership() external payable onlyActiveMember {
        Member storage member = members[msg.sender];
        require(msg.value >= tierFees[member.tier], "Insufficient payment for renewal");

        member.expiryTimestamp += 365 days;


        if (msg.value > tierFees[member.tier]) {
            payable(msg.sender).transfer(msg.value - tierFees[member.tier]);
        }

        emit MembershipRenewed(msg.sender, member.expiryTimestamp);
    }


    function addLoyaltyPoints(address _member, uint16 _points) external onlyOwner {
        require(members[_member].isActive, "Member is not active");
        _addLoyaltyPoints(_member, _points);
    }


    function _addLoyaltyPoints(address _member, uint16 _points) internal {
        Member storage member = members[_member];
        uint32 newPoints = uint32(member.loyaltyPoints) + uint32(_points);


        if (newPoints > type(uint16).max) {
            member.loyaltyPoints = type(uint16).max;
        } else {
            member.loyaltyPoints = uint16(newPoints);
        }

        emit LoyaltyPointsUpdated(_member, member.loyaltyPoints);
    }


    function useLoyaltyPoints(uint16 _points) external onlyActiveMember {
        Member storage member = members[msg.sender];
        require(member.loyaltyPoints >= _points, "Insufficient loyalty points");

        member.loyaltyPoints -= _points;
        emit LoyaltyPointsUpdated(msg.sender, member.loyaltyPoints);
    }


    function deactivateMember(address _member) external onlyOwner {
        require(members[_member].isActive, "Member is already inactive");
        members[_member].isActive = false;
        emit MemberDeactivated(_member);
    }


    function isMemberActive(address _member) external view returns (bool) {
        Member memory member = members[_member];
        return member.isActive && member.expiryTimestamp > block.timestamp;
    }


    function getMemberInfo(address _member) external view returns (
        bytes32 memberId,
        MembershipTier tier,
        uint32 joinTimestamp,
        uint32 expiryTimestamp,
        uint16 loyaltyPoints,
        bool isActive,
        bytes32 referralCode
    ) {
        Member memory member = members[_member];
        return (
            member.memberId,
            member.tier,
            member.joinTimestamp,
            member.expiryTimestamp,
            member.loyaltyPoints,
            member.isActive,
            member.referralCode
        );
    }


    function getMemberByMemberId(bytes32 _memberId) external view returns (address) {
        return memberIdToAddress[_memberId];
    }


    function getMemberByReferralCode(bytes32 _referralCode) external view returns (address) {
        return referralCodeToAddress[_referralCode];
    }


    function updateTierFee(MembershipTier _tier, uint256 _newFee) external onlyOwner validTier(_tier) {
        tierFees[_tier] = _newFee;
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
