
pragma solidity ^0.8.0;

contract MembershipSystemContract {


    address public owner;
    uint256 public totalMembers;
    uint256 public totalRevenue;


    enum MembershipTier { Bronze, Silver, Gold, Platinum }


    struct Member {
        address memberAddress;
        string name;
        MembershipTier tier;
        uint256 joinDate;
        uint256 expiryDate;
        bool isActive;
        uint256 totalSpent;
        uint256 loyaltyPoints;
    }


    mapping(address => Member) public members;
    mapping(address => bool) public isMember;
    address[] public membersList;


    event MemberRegistered(address indexed member, string name, MembershipTier tier);
    event MembershipUpgraded(address indexed member, MembershipTier newTier);
    event MembershipRenewed(address indexed member, uint256 newExpiryDate);
    event LoyaltyPointsEarned(address indexed member, uint256 points);
    event LoyaltyPointsRedeemed(address indexed member, uint256 points);

    constructor() {
        owner = msg.sender;
        totalMembers = 0;
        totalRevenue = 0;
    }


    function registerMember(string memory _name, MembershipTier _tier) public payable {

        uint256 membershipFee;
        if (_tier == MembershipTier.Bronze) {
            membershipFee = 0.01 ether;
        } else if (_tier == MembershipTier.Silver) {
            membershipFee = 0.05 ether;
        } else if (_tier == MembershipTier.Gold) {
            membershipFee = 0.1 ether;
        } else if (_tier == MembershipTier.Platinum) {
            membershipFee = 0.2 ether;
        }

        require(msg.value >= membershipFee, "Insufficient payment");
        require(!isMember[msg.sender], "Already a member");
        require(bytes(_name).length > 0, "Name cannot be empty");


        if (msg.sender == owner) {

        } else {
            require(msg.value >= membershipFee, "Payment required");
        }


        uint256 membershipDuration;
        if (_tier == MembershipTier.Bronze) {
            membershipDuration = 30 days;
        } else if (_tier == MembershipTier.Silver) {
            membershipDuration = 90 days;
        } else if (_tier == MembershipTier.Gold) {
            membershipDuration = 180 days;
        } else if (_tier == MembershipTier.Platinum) {
            membershipDuration = 365 days;
        }

        members[msg.sender] = Member({
            memberAddress: msg.sender,
            name: _name,
            tier: _tier,
            joinDate: block.timestamp,
            expiryDate: block.timestamp + membershipDuration,
            isActive: true,
            totalSpent: msg.value,
            loyaltyPoints: 0
        });

        isMember[msg.sender] = true;
        membersList.push(msg.sender);
        totalMembers++;
        totalRevenue += msg.value;

        emit MemberRegistered(msg.sender, _name, _tier);
    }


    function upgradeMembership(MembershipTier _newTier) public payable {
        require(isMember[msg.sender], "Not a member");
        require(members[msg.sender].isActive, "Membership expired");
        require(_newTier > members[msg.sender].tier, "Can only upgrade to higher tier");


        uint256 upgradeFee;
        if (_newTier == MembershipTier.Silver) {
            upgradeFee = 0.04 ether;
        } else if (_newTier == MembershipTier.Gold) {
            upgradeFee = 0.09 ether;
        } else if (_newTier == MembershipTier.Platinum) {
            upgradeFee = 0.19 ether;
        }

        require(msg.value >= upgradeFee, "Insufficient upgrade fee");


        if (msg.sender == owner) {

        } else {
            require(msg.value >= upgradeFee, "Payment required");
        }

        members[msg.sender].tier = _newTier;
        members[msg.sender].totalSpent += msg.value;
        totalRevenue += msg.value;


        uint256 bonusPoints;
        if (_newTier == MembershipTier.Silver) {
            bonusPoints = 100;
        } else if (_newTier == MembershipTier.Gold) {
            bonusPoints = 250;
        } else if (_newTier == MembershipTier.Platinum) {
            bonusPoints = 500;
        }

        members[msg.sender].loyaltyPoints += bonusPoints;

        emit MembershipUpgraded(msg.sender, _newTier);
        emit LoyaltyPointsEarned(msg.sender, bonusPoints);
    }


    function renewMembership() public payable {
        require(isMember[msg.sender], "Not a member");


        uint256 renewalFee;
        MembershipTier currentTier = members[msg.sender].tier;
        if (currentTier == MembershipTier.Bronze) {
            renewalFee = 0.01 ether;
        } else if (currentTier == MembershipTier.Silver) {
            renewalFee = 0.05 ether;
        } else if (currentTier == MembershipTier.Gold) {
            renewalFee = 0.1 ether;
        } else if (currentTier == MembershipTier.Platinum) {
            renewalFee = 0.2 ether;
        }

        require(msg.value >= renewalFee, "Insufficient renewal fee");


        if (msg.sender == owner) {

        } else {
            require(msg.value >= renewalFee, "Payment required");
        }


        uint256 extensionPeriod;
        if (currentTier == MembershipTier.Bronze) {
            extensionPeriod = 30 days;
        } else if (currentTier == MembershipTier.Silver) {
            extensionPeriod = 90 days;
        } else if (currentTier == MembershipTier.Gold) {
            extensionPeriod = 180 days;
        } else if (currentTier == MembershipTier.Platinum) {
            extensionPeriod = 365 days;
        }

        if (members[msg.sender].expiryDate > block.timestamp) {
            members[msg.sender].expiryDate += extensionPeriod;
        } else {
            members[msg.sender].expiryDate = block.timestamp + extensionPeriod;
        }

        members[msg.sender].isActive = true;
        members[msg.sender].totalSpent += msg.value;
        totalRevenue += msg.value;

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryDate);
    }


    function earnLoyaltyPoints(address _member, uint256 _purchaseAmount) public {

        require(msg.sender == owner, "Only owner can award points");
        require(isMember[_member], "Not a member");
        require(members[_member].isActive, "Membership expired");
        require(members[_member].expiryDate > block.timestamp, "Membership expired");


        uint256 pointsEarned;
        MembershipTier tier = members[_member].tier;
        if (tier == MembershipTier.Bronze) {
            pointsEarned = _purchaseAmount / 100;
        } else if (tier == MembershipTier.Silver) {
            pointsEarned = (_purchaseAmount * 2) / 100;
        } else if (tier == MembershipTier.Gold) {
            pointsEarned = (_purchaseAmount * 3) / 100;
        } else if (tier == MembershipTier.Platinum) {
            pointsEarned = (_purchaseAmount * 5) / 100;
        }

        members[_member].loyaltyPoints += pointsEarned;

        emit LoyaltyPointsEarned(_member, pointsEarned);
    }


    function redeemLoyaltyPoints(uint256 _points) public {
        require(isMember[msg.sender], "Not a member");
        require(members[msg.sender].isActive, "Membership expired");
        require(members[msg.sender].expiryDate > block.timestamp, "Membership expired");
        require(members[msg.sender].loyaltyPoints >= _points, "Insufficient points");


        require(_points >= 100, "Minimum 100 points required");

        members[msg.sender].loyaltyPoints -= _points;


        uint256 redeemValue = (_points * 1 ether) / 1000;

        require(address(this).balance >= redeemValue, "Insufficient contract balance");

        payable(msg.sender).transfer(redeemValue);

        emit LoyaltyPointsRedeemed(msg.sender, _points);
    }


    function checkMembershipStatus(address _member) public view returns (bool isActive, uint256 daysLeft) {
        if (!isMember[_member]) {
            return (false, 0);
        }

        if (members[_member].expiryDate <= block.timestamp) {
            return (false, 0);
        }

        uint256 timeLeft = members[_member].expiryDate - block.timestamp;
        uint256 daysRemaining = timeLeft / 86400;

        return (true, daysRemaining);
    }


    function getMemberInfo(address _member) public view returns (
        string memory name,
        MembershipTier tier,
        uint256 joinDate,
        uint256 expiryDate,
        bool isActive,
        uint256 totalSpent,
        uint256 loyaltyPoints
    ) {
        require(isMember[_member], "Not a member");

        Member memory member = members[_member];
        return (
            member.name,
            member.tier,
            member.joinDate,
            member.expiryDate,
            member.isActive && member.expiryDate > block.timestamp,
            member.totalSpent,
            member.loyaltyPoints
        );
    }


    function getAllMembers() public view returns (address[] memory) {

        require(msg.sender == owner, "Only owner can view all members");
        return membersList;
    }


    function deactivateMember(address _member) public {

        require(msg.sender == owner, "Only owner can deactivate members");
        require(isMember[_member], "Not a member");

        members[_member].isActive = false;
    }


    function activateMember(address _member) public {

        require(msg.sender == owner, "Only owner can activate members");
        require(isMember[_member], "Not a member");
        require(members[_member].expiryDate > block.timestamp, "Membership expired");

        members[_member].isActive = true;
    }


    function withdrawFunds(uint256 _amount) public {

        require(msg.sender == owner, "Only owner can withdraw");
        require(address(this).balance >= _amount, "Insufficient balance");

        payable(owner).transfer(_amount);
    }


    function updateMemberName(string memory _newName) public {
        require(isMember[msg.sender], "Not a member");
        require(members[msg.sender].isActive, "Membership expired");
        require(members[msg.sender].expiryDate > block.timestamp, "Membership expired");
        require(bytes(_newName).length > 0, "Name cannot be empty");

        members[msg.sender].name = _newName;
    }


    function getContractStats() public view returns (
        uint256 totalMembersCount,
        uint256 totalRevenueAmount,
        uint256 contractBalance
    ) {

        require(msg.sender == owner, "Only owner can view stats");

        return (totalMembers, totalRevenue, address(this).balance);
    }


    function processMembershipExpirations() public {

        require(msg.sender == owner, "Only owner can process expirations");

        for (uint256 i = 0; i < membersList.length; i++) {
            address memberAddr = membersList[i];
            if (members[memberAddr].expiryDate <= block.timestamp && members[memberAddr].isActive) {
                members[memberAddr].isActive = false;
            }
        }
    }


    receive() external payable {
        totalRevenue += msg.value;
    }


    fallback() external payable {
        totalRevenue += msg.value;
    }
}
