
pragma solidity ^0.8.0;

contract MembershipSystem {

    enum MembershipTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM
    }


    struct Member {
        bytes32 membershipId;
        MembershipTier tier;
        uint32 joinTimestamp;
        uint32 expiryTimestamp;
        uint16 points;
        bool isActive;
        bytes32 referralCode;
    }


    mapping(address => Member) public members;
    mapping(bytes32 => address) public membershipIdToAddress;
    mapping(bytes32 => address) public referralCodeToAddress;

    address public owner;
    uint32 public totalMembers;
    uint16 public constant BRONZE_THRESHOLD = 0;
    uint16 public constant SILVER_THRESHOLD = 100;
    uint16 public constant GOLD_THRESHOLD = 500;
    uint16 public constant PLATINUM_THRESHOLD = 1000;


    event MemberRegistered(address indexed member, bytes32 membershipId, MembershipTier tier);
    event MembershipUpgraded(address indexed member, MembershipTier newTier);
    event PointsAdded(address indexed member, uint16 points);
    event MembershipRenewed(address indexed member, uint32 newExpiryTimestamp);
    event MembershipDeactivated(address indexed member);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Member is not active");
        require(members[msg.sender].expiryTimestamp > block.timestamp, "Membership expired");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalMembers = 0;
    }


    function registerMember(
        bytes32 _membershipId,
        bytes32 _referralCode,
        uint32 _durationDays
    ) external validAddress(msg.sender) {
        require(!members[msg.sender].isActive, "Already a member");
        require(membershipIdToAddress[_membershipId] == address(0), "Membership ID already exists");
        require(_durationDays > 0, "Duration must be positive");

        uint32 expiryTimestamp = uint32(block.timestamp) + (_durationDays * 1 days);
        bytes32 uniqueReferralCode = keccak256(abi.encodePacked(msg.sender, block.timestamp));

        members[msg.sender] = Member({
            membershipId: _membershipId,
            tier: MembershipTier.BRONZE,
            joinTimestamp: uint32(block.timestamp),
            expiryTimestamp: expiryTimestamp,
            points: 0,
            isActive: true,
            referralCode: uniqueReferralCode
        });

        membershipIdToAddress[_membershipId] = msg.sender;
        referralCodeToAddress[uniqueReferralCode] = msg.sender;
        totalMembers++;


        if (_referralCode != bytes32(0) && referralCodeToAddress[_referralCode] != address(0)) {
            address referrer = referralCodeToAddress[_referralCode];
            if (members[referrer].isActive) {
                _addPoints(referrer, 50);
            }
        }

        emit MemberRegistered(msg.sender, _membershipId, MembershipTier.BRONZE);
    }


    function addPoints(address _member, uint16 _points) external onlyOwner validAddress(_member) {
        require(members[_member].isActive, "Member is not active");
        _addPoints(_member, _points);
    }


    function _addPoints(address _member, uint16 _points) internal {
        Member storage member = members[_member];
        member.points += _points;

        MembershipTier newTier = _calculateTier(member.points);
        if (newTier != member.tier) {
            member.tier = newTier;
            emit MembershipUpgraded(_member, newTier);
        }

        emit PointsAdded(_member, _points);
    }


    function _calculateTier(uint16 _points) internal pure returns (MembershipTier) {
        if (_points >= PLATINUM_THRESHOLD) {
            return MembershipTier.PLATINUM;
        } else if (_points >= GOLD_THRESHOLD) {
            return MembershipTier.GOLD;
        } else if (_points >= SILVER_THRESHOLD) {
            return MembershipTier.SILVER;
        } else {
            return MembershipTier.BRONZE;
        }
    }


    function renewMembership(uint32 _additionalDays) external onlyActiveMember {
        require(_additionalDays > 0, "Additional days must be positive");

        Member storage member = members[msg.sender];
        member.expiryTimestamp += (_additionalDays * 1 days);

        emit MembershipRenewed(msg.sender, member.expiryTimestamp);
    }


    function deactivateMember(address _member) external onlyOwner validAddress(_member) {
        require(members[_member].isActive, "Member is already inactive");

        members[_member].isActive = false;
        totalMembers--;

        emit MembershipDeactivated(_member);
    }


    function getMemberInfo(address _member) external view returns (
        bytes32 membershipId,
        MembershipTier tier,
        uint32 joinTimestamp,
        uint32 expiryTimestamp,
        uint16 points,
        bool isActive,
        bytes32 referralCode
    ) {
        Member memory member = members[_member];
        return (
            member.membershipId,
            member.tier,
            member.joinTimestamp,
            member.expiryTimestamp,
            member.points,
            member.isActive,
            member.referralCode
        );
    }


    function isValidMember(address _member) external view returns (bool) {
        Member memory member = members[_member];
        return member.isActive && member.expiryTimestamp > block.timestamp;
    }


    function getTierName(MembershipTier _tier) external pure returns (string memory) {
        if (_tier == MembershipTier.BRONZE) {
            return "Bronze";
        } else if (_tier == MembershipTier.SILVER) {
            return "Silver";
        } else if (_tier == MembershipTier.GOLD) {
            return "Gold";
        } else {
            return "Platinum";
        }
    }


    function transferOwnership(address _newOwner) external onlyOwner validAddress(_newOwner) {
        owner = _newOwner;
    }
}
