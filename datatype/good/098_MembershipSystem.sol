
pragma solidity ^0.8.0;

contract MembershipSystem {

    enum MembershipTier {
        Bronze,
        Silver,
        Gold,
        Platinum,
        Diamond
    }


    struct Member {
        bytes32 memberId;
        address memberAddress;
        MembershipTier tier;
        uint64 joinTimestamp;
        uint64 expiryTimestamp;
        uint32 points;
        bool isActive;
        bytes32 referralCode;
    }


    address public owner;
    uint32 public totalMembers;
    uint32 public activeMemberCount;


    mapping(address => Member) public members;
    mapping(bytes32 => address) public memberIdToAddress;
    mapping(bytes32 => address) public referralCodeToAddress;
    mapping(address => bool) public isMember;


    mapping(MembershipTier => uint256) public tierFees;


    event MemberRegistered(address indexed memberAddress, bytes32 memberId, MembershipTier tier);
    event MembershipUpgraded(address indexed memberAddress, MembershipTier newTier);
    event MembershipRenewed(address indexed memberAddress, uint64 newExpiryTimestamp);
    event PointsAwarded(address indexed memberAddress, uint32 points);
    event MembershipDeactivated(address indexed memberAddress);
    event MembershipReactivated(address indexed memberAddress);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(isMember[msg.sender], "Not a member");
        require(members[msg.sender].isActive, "Membership not active");
        require(members[msg.sender].expiryTimestamp > block.timestamp, "Membership expired");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;


        tierFees[MembershipTier.Bronze] = 0.01 ether;
        tierFees[MembershipTier.Silver] = 0.05 ether;
        tierFees[MembershipTier.Gold] = 0.1 ether;
        tierFees[MembershipTier.Platinum] = 0.5 ether;
        tierFees[MembershipTier.Diamond] = 1 ether;
    }


    function registerMember(
        MembershipTier _tier,
        bytes32 _referralCode
    ) external payable validAddress(msg.sender) {
        require(!isMember[msg.sender], "Already a member");
        require(msg.value >= tierFees[_tier], "Insufficient payment");


        if (_referralCode != bytes32(0)) {
            require(referralCodeToAddress[_referralCode] != address(0), "Invalid referral code");
            require(referralCodeToAddress[_referralCode] != msg.sender, "Cannot refer yourself");
        }

        bytes32 memberId = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalMembers));
        bytes32 newReferralCode = keccak256(abi.encodePacked(memberId, "referral"));

        uint64 currentTime = uint64(block.timestamp);
        uint64 expiryTime = currentTime + 365 days;

        members[msg.sender] = Member({
            memberId: memberId,
            memberAddress: msg.sender,
            tier: _tier,
            joinTimestamp: currentTime,
            expiryTimestamp: expiryTime,
            points: 100,
            isActive: true,
            referralCode: newReferralCode
        });

        memberIdToAddress[memberId] = msg.sender;
        referralCodeToAddress[newReferralCode] = msg.sender;
        isMember[msg.sender] = true;

        totalMembers++;
        activeMemberCount++;


        if (_referralCode != bytes32(0)) {
            address referrer = referralCodeToAddress[_referralCode];
            if (members[referrer].isActive && members[referrer].expiryTimestamp > block.timestamp) {
                members[referrer].points += 50;
                emit PointsAwarded(referrer, 50);
            }
        }

        emit MemberRegistered(msg.sender, memberId, _tier);


        if (msg.value > tierFees[_tier]) {
            payable(msg.sender).transfer(msg.value - tierFees[_tier]);
        }
    }


    function upgradeMembership(MembershipTier _newTier) external payable onlyActiveMember {
        require(uint8(_newTier) > uint8(members[msg.sender].tier), "Can only upgrade to higher tier");

        uint256 currentTierFee = tierFees[members[msg.sender].tier];
        uint256 newTierFee = tierFees[_newTier];
        uint256 upgradeFee = newTierFee - currentTierFee;

        require(msg.value >= upgradeFee, "Insufficient payment for upgrade");

        members[msg.sender].tier = _newTier;
        members[msg.sender].points += 200;

        emit MembershipUpgraded(msg.sender, _newTier);
        emit PointsAwarded(msg.sender, 200);


        if (msg.value > upgradeFee) {
            payable(msg.sender).transfer(msg.value - upgradeFee);
        }
    }


    function renewMembership() external payable onlyActiveMember {
        uint256 renewalFee = tierFees[members[msg.sender].tier];
        require(msg.value >= renewalFee, "Insufficient payment for renewal");

        members[msg.sender].expiryTimestamp += 365 days;
        members[msg.sender].points += 50;

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryTimestamp);
        emit PointsAwarded(msg.sender, 50);


        if (msg.value > renewalFee) {
            payable(msg.sender).transfer(msg.value - renewalFee);
        }
    }


    function awardPoints(address _member, uint32 _points) external onlyOwner validAddress(_member) {
        require(isMember[_member], "Not a member");
        require(members[_member].isActive, "Member not active");

        members[_member].points += _points;
        emit PointsAwarded(_member, _points);
    }


    function usePoints(uint32 _points) external onlyActiveMember {
        require(members[msg.sender].points >= _points, "Insufficient points");
        members[msg.sender].points -= _points;
    }


    function deactivateMember(address _member) external onlyOwner validAddress(_member) {
        require(isMember[_member], "Not a member");
        require(members[_member].isActive, "Already deactivated");

        members[_member].isActive = false;
        activeMemberCount--;

        emit MembershipDeactivated(_member);
    }


    function reactivateMember(address _member) external onlyOwner validAddress(_member) {
        require(isMember[_member], "Not a member");
        require(!members[_member].isActive, "Already active");

        members[_member].isActive = true;
        activeMemberCount++;

        emit MembershipReactivated(_member);
    }


    function updateTierFee(MembershipTier _tier, uint256 _newFee) external onlyOwner {
        tierFees[_tier] = _newFee;
    }


    function getMemberInfo(address _member) external view returns (
        bytes32 memberId,
        MembershipTier tier,
        uint64 joinTimestamp,
        uint64 expiryTimestamp,
        uint32 points,
        bool isActive,
        bytes32 referralCode
    ) {
        require(isMember[_member], "Not a member");
        Member memory member = members[_member];
        return (
            member.memberId,
            member.tier,
            member.joinTimestamp,
            member.expiryTimestamp,
            member.points,
            member.isActive,
            member.referralCode
        );
    }


    function isValidMember(address _member) external view returns (bool) {
        return isMember[_member] &&
               members[_member].isActive &&
               members[_member].expiryTimestamp > block.timestamp;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(owner).transfer(_amount);
    }


    function transferOwnership(address _newOwner) external onlyOwner validAddress(_newOwner) {
        owner = _newOwner;
    }
}
