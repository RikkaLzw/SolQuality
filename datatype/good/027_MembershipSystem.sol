
pragma solidity ^0.8.0;

contract MembershipSystem {
    address public owner;
    uint256 public totalMembers;

    enum MembershipTier { NONE, BRONZE, SILVER, GOLD, PLATINUM }

    struct Member {
        bytes32 memberId;
        address memberAddress;
        MembershipTier tier;
        uint64 joinTimestamp;
        uint64 expiryTimestamp;
        bool isActive;
        uint128 totalSpent;
        bytes32 referralCode;
    }

    mapping(address => Member) public members;
    mapping(bytes32 => address) public memberIdToAddress;
    mapping(bytes32 => bool) public usedReferralCodes;

    uint256 public constant BRONZE_FEE = 0.01 ether;
    uint256 public constant SILVER_FEE = 0.05 ether;
    uint256 public constant GOLD_FEE = 0.1 ether;
    uint256 public constant PLATINUM_FEE = 0.2 ether;

    uint32 public constant MEMBERSHIP_DURATION = 365 days;

    event MemberRegistered(address indexed member, bytes32 memberId, MembershipTier tier);
    event MembershipUpgraded(address indexed member, MembershipTier oldTier, MembershipTier newTier);
    event MembershipRenewed(address indexed member, uint64 newExpiryTimestamp);
    event MembershipDeactivated(address indexed member);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive && block.timestamp < members[msg.sender].expiryTimestamp, "Not an active member");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerMember(MembershipTier _tier, bytes32 _referralCode) external payable {
        require(_tier != MembershipTier.NONE, "Invalid membership tier");
        require(members[msg.sender].memberAddress == address(0), "Already registered");

        uint256 requiredFee = getMembershipFee(_tier);
        require(msg.value >= requiredFee, "Insufficient payment");

        if (_referralCode != bytes32(0)) {
            require(usedReferralCodes[_referralCode], "Invalid referral code");
        }

        bytes32 memberId = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalMembers));
        bytes32 newReferralCode = keccak256(abi.encodePacked(memberId, "referral"));

        members[msg.sender] = Member({
            memberId: memberId,
            memberAddress: msg.sender,
            tier: _tier,
            joinTimestamp: uint64(block.timestamp),
            expiryTimestamp: uint64(block.timestamp + MEMBERSHIP_DURATION),
            isActive: true,
            totalSpent: uint128(msg.value),
            referralCode: newReferralCode
        });

        memberIdToAddress[memberId] = msg.sender;
        usedReferralCodes[newReferralCode] = true;
        totalMembers++;

        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        emit MemberRegistered(msg.sender, memberId, _tier);
    }

    function upgradeMembership(MembershipTier _newTier) external payable onlyActiveMember {
        require(_newTier > members[msg.sender].tier, "Can only upgrade to higher tier");

        uint256 currentFee = getMembershipFee(members[msg.sender].tier);
        uint256 newFee = getMembershipFee(_newTier);
        uint256 upgradeFee = newFee - currentFee;

        require(msg.value >= upgradeFee, "Insufficient upgrade fee");

        MembershipTier oldTier = members[msg.sender].tier;
        members[msg.sender].tier = _newTier;
        members[msg.sender].totalSpent += uint128(msg.value);

        if (msg.value > upgradeFee) {
            payable(msg.sender).transfer(msg.value - upgradeFee);
        }

        emit MembershipUpgraded(msg.sender, oldTier, _newTier);
    }

    function renewMembership() external payable onlyActiveMember {
        uint256 renewalFee = getMembershipFee(members[msg.sender].tier);
        require(msg.value >= renewalFee, "Insufficient renewal fee");

        members[msg.sender].expiryTimestamp = uint64(block.timestamp + MEMBERSHIP_DURATION);
        members[msg.sender].totalSpent += uint128(msg.value);

        if (msg.value > renewalFee) {
            payable(msg.sender).transfer(msg.value - renewalFee);
        }

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryTimestamp);
    }

    function deactivateMembership() external onlyActiveMember {
        members[msg.sender].isActive = false;
        emit MembershipDeactivated(msg.sender);
    }

    function getMembershipFee(MembershipTier _tier) public pure returns (uint256) {
        if (_tier == MembershipTier.BRONZE) return BRONZE_FEE;
        if (_tier == MembershipTier.SILVER) return SILVER_FEE;
        if (_tier == MembershipTier.GOLD) return GOLD_FEE;
        if (_tier == MembershipTier.PLATINUM) return PLATINUM_FEE;
        return 0;
    }

    function getMemberInfo(address _member) external view returns (
        bytes32 memberId,
        MembershipTier tier,
        uint64 joinTimestamp,
        uint64 expiryTimestamp,
        bool isActive,
        uint128 totalSpent,
        bytes32 referralCode
    ) {
        Member memory member = members[_member];
        return (
            member.memberId,
            member.tier,
            member.joinTimestamp,
            member.expiryTimestamp,
            member.isActive,
            member.totalSpent,
            member.referralCode
        );
    }

    function isMembershipValid(address _member) external view returns (bool) {
        return members[_member].isActive && block.timestamp < members[_member].expiryTimestamp;
    }

    function withdrawFunds() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
    }
}
