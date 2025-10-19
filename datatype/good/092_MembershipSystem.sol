
pragma solidity ^0.8.0;

contract MembershipSystem {
    address public owner;
    uint256 public totalMembers;
    uint256 public nextMemberId;

    enum MembershipTier { BASIC, PREMIUM, VIP }

    struct Member {
        uint256 memberId;
        address memberAddress;
        bytes32 name;
        MembershipTier tier;
        uint256 joinTimestamp;
        uint256 expiryTimestamp;
        bool isActive;
        uint256 totalSpent;
        bytes32 referralCode;
    }

    mapping(address => Member) public members;
    mapping(uint256 => address) public memberIdToAddress;
    mapping(bytes32 => address) public referralCodeToAddress;
    mapping(address => bool) public isMember;

    uint256 public constant BASIC_FEE = 0.01 ether;
    uint256 public constant PREMIUM_FEE = 0.05 ether;
    uint256 public constant VIP_FEE = 0.1 ether;

    uint256 public constant BASIC_DURATION = 30 days;
    uint256 public constant PREMIUM_DURATION = 90 days;
    uint256 public constant VIP_DURATION = 365 days;

    event MemberRegistered(address indexed member, uint256 memberId, MembershipTier tier);
    event MembershipRenewed(address indexed member, uint256 newExpiryTimestamp);
    event MembershipUpgraded(address indexed member, MembershipTier newTier);
    event MemberDeactivated(address indexed member);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(isMember[msg.sender] && members[msg.sender].isActive, "Only active members can call this function");
        require(block.timestamp <= members[msg.sender].expiryTimestamp, "Membership expired");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextMemberId = 1;
    }

    function registerMember(
        bytes32 _name,
        MembershipTier _tier,
        bytes32 _referralCode
    ) external payable {
        require(!isMember[msg.sender], "Already a member");
        require(_name != bytes32(0), "Name cannot be empty");

        uint256 fee = getMembershipFee(_tier);
        require(msg.value >= fee, "Insufficient payment");

        if (_referralCode != bytes32(0)) {
            require(referralCodeToAddress[_referralCode] == address(0), "Referral code already exists");
        }

        uint256 duration = getMembershipDuration(_tier);
        uint256 expiryTimestamp = block.timestamp + duration;

        Member memory newMember = Member({
            memberId: nextMemberId,
            memberAddress: msg.sender,
            name: _name,
            tier: _tier,
            joinTimestamp: block.timestamp,
            expiryTimestamp: expiryTimestamp,
            isActive: true,
            totalSpent: msg.value,
            referralCode: _referralCode
        });

        members[msg.sender] = newMember;
        memberIdToAddress[nextMemberId] = msg.sender;
        isMember[msg.sender] = true;

        if (_referralCode != bytes32(0)) {
            referralCodeToAddress[_referralCode] = msg.sender;
        }

        totalMembers++;
        nextMemberId++;

        emit MemberRegistered(msg.sender, newMember.memberId, _tier);

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    function renewMembership() external payable onlyActiveMember {
        Member storage member = members[msg.sender];
        uint256 fee = getMembershipFee(member.tier);
        require(msg.value >= fee, "Insufficient payment");

        uint256 duration = getMembershipDuration(member.tier);
        uint256 newExpiryTimestamp;

        if (block.timestamp > member.expiryTimestamp) {
            newExpiryTimestamp = block.timestamp + duration;
        } else {
            newExpiryTimestamp = member.expiryTimestamp + duration;
        }

        member.expiryTimestamp = newExpiryTimestamp;
        member.totalSpent += msg.value;

        emit MembershipRenewed(msg.sender, newExpiryTimestamp);

        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    function upgradeMembership(MembershipTier _newTier) external payable onlyActiveMember {
        Member storage member = members[msg.sender];
        require(_newTier > member.tier, "Can only upgrade to higher tier");

        uint256 currentFee = getMembershipFee(member.tier);
        uint256 newFee = getMembershipFee(_newTier);
        uint256 upgradeFee = newFee - currentFee;

        require(msg.value >= upgradeFee, "Insufficient payment for upgrade");

        member.tier = _newTier;
        member.totalSpent += msg.value;

        uint256 newDuration = getMembershipDuration(_newTier);
        uint256 remainingTime = member.expiryTimestamp > block.timestamp ?
            member.expiryTimestamp - block.timestamp : 0;

        member.expiryTimestamp = block.timestamp + newDuration + remainingTime;

        emit MembershipUpgraded(msg.sender, _newTier);

        if (msg.value > upgradeFee) {
            payable(msg.sender).transfer(msg.value - upgradeFee);
        }
    }

    function deactivateMember(address _member) external onlyOwner {
        require(isMember[_member], "Not a member");
        members[_member].isActive = false;
        emit MemberDeactivated(_member);
    }

    function getMemberInfo(address _member) external view returns (
        uint256 memberId,
        bytes32 name,
        MembershipTier tier,
        uint256 joinTimestamp,
        uint256 expiryTimestamp,
        bool isActive,
        uint256 totalSpent,
        bytes32 referralCode
    ) {
        require(isMember[_member], "Not a member");
        Member memory member = members[_member];
        return (
            member.memberId,
            member.name,
            member.tier,
            member.joinTimestamp,
            member.expiryTimestamp,
            member.isActive,
            member.totalSpent,
            member.referralCode
        );
    }

    function isMembershipValid(address _member) external view returns (bool) {
        if (!isMember[_member] || !members[_member].isActive) {
            return false;
        }
        return block.timestamp <= members[_member].expiryTimestamp;
    }

    function getMembershipFee(MembershipTier _tier) public pure returns (uint256) {
        if (_tier == MembershipTier.BASIC) {
            return BASIC_FEE;
        } else if (_tier == MembershipTier.PREMIUM) {
            return PREMIUM_FEE;
        } else if (_tier == MembershipTier.VIP) {
            return VIP_FEE;
        }
        revert("Invalid membership tier");
    }

    function getMembershipDuration(MembershipTier _tier) public pure returns (uint256) {
        if (_tier == MembershipTier.BASIC) {
            return BASIC_DURATION;
        } else if (_tier == MembershipTier.PREMIUM) {
            return PREMIUM_DURATION;
        } else if (_tier == MembershipTier.VIP) {
            return VIP_DURATION;
        }
        revert("Invalid membership tier");
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }
}
