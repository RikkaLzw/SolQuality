
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address public owner;
    uint256 public membershipFee;
    uint256 public totalMembers;

    enum MembershipTier { BASIC, PREMIUM, VIP }

    struct Member {
        bool isActive;
        MembershipTier tier;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
    }

    mapping(address => Member) public members;
    mapping(address => bool) public admins;


    event MemberJoined(address member, MembershipTier tier);
    event MembershipRenewed(address member, uint256 newExpiry);
    event TierUpgraded(address member, MembershipTier newTier);
    event AdminAdded(address admin);


    error NotAllowed();
    error Invalid();
    error Failed();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner);
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive && block.timestamp < members[msg.sender].expiryDate);
        _;
    }

    constructor(uint256 _membershipFee) {
        owner = msg.sender;
        membershipFee = _membershipFee;
        admins[msg.sender] = true;
    }

    function joinMembership(MembershipTier _tier) external payable {
        require(!members[msg.sender].isActive);

        uint256 requiredFee = calculateFee(_tier);
        require(msg.value >= requiredFee);

        members[msg.sender] = Member({
            isActive: true,
            tier: _tier,
            joinDate: block.timestamp,
            expiryDate: block.timestamp + 365 days,
            totalSpent: msg.value
        });

        totalMembers++;




        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }
    }

    function renewMembership() external payable onlyActiveMember {
        uint256 requiredFee = calculateFee(members[msg.sender].tier);
        require(msg.value >= requiredFee);

        members[msg.sender].expiryDate += 365 days;
        members[msg.sender].totalSpent += msg.value;

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryDate);

        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }
    }

    function upgradeTier(MembershipTier _newTier) external payable onlyActiveMember {
        require(_newTier > members[msg.sender].tier);

        uint256 upgradeFee = calculateUpgradeFee(members[msg.sender].tier, _newTier);
        require(msg.value >= upgradeFee);

        members[msg.sender].tier = _newTier;
        members[msg.sender].totalSpent += msg.value;

        emit TierUpgraded(msg.sender, _newTier);

        if (msg.value > upgradeFee) {
            payable(msg.sender).transfer(msg.value - upgradeFee);
        }
    }

    function deactivateMembership(address _member) external onlyAdmin {
        require(members[_member].isActive);

        members[_member].isActive = false;
        totalMembers--;



    }

    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0));
        require(!admins[_admin]);

        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner);
        require(admins[_admin]);

        admins[_admin] = false;



    }

    function updateMembershipFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0);

        membershipFee = _newFee;



    }

    function extendMembership(address _member, uint256 _days) external onlyAdmin {
        require(members[_member].isActive);
        require(_days > 0);

        members[_member].expiryDate += _days * 1 days;



    }

    function calculateFee(MembershipTier _tier) public view returns (uint256) {
        if (_tier == MembershipTier.BASIC) {
            return membershipFee;
        } else if (_tier == MembershipTier.PREMIUM) {
            return membershipFee * 2;
        } else {
            return membershipFee * 3;
        }
    }

    function calculateUpgradeFee(MembershipTier _currentTier, MembershipTier _newTier) public view returns (uint256) {
        return calculateFee(_newTier) - calculateFee(_currentTier);
    }

    function getMemberInfo(address _member) external view returns (Member memory) {
        return members[_member];
    }

    function isMemberActive(address _member) external view returns (bool) {
        return members[_member].isActive && block.timestamp < members[_member].expiryDate;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);

        payable(owner).transfer(balance);



    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        require(_newOwner != owner);




        owner = _newOwner;
        admins[_newOwner] = true;



    }

    receive() external payable {


    }
}
