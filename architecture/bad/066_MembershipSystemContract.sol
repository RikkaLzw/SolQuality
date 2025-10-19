
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address owner;
    mapping(address => bool) members;
    mapping(address => uint256) membershipExpiry;
    mapping(address => uint256) membershipLevel;
    mapping(address => uint256) memberPoints;
    mapping(address => bool) premiumMembers;
    mapping(address => uint256) joinTimestamp;
    uint256 totalMembers;
    uint256 totalRevenue;
    bool contractActive;

    event MemberJoined(address member, uint256 level);
    event MembershipRenewed(address member, uint256 newExpiry);
    event PointsAwarded(address member, uint256 points);
    event MemberUpgraded(address member, uint256 newLevel);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        totalMembers = 0;
        totalRevenue = 0;
    }

    function joinMembership(uint256 level) public payable {
        if (msg.sender == owner) {
            revert("Owner cannot be member");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[msg.sender] == true) {
            revert("Already a member");
        }
        if (level < 1 || level > 3) {
            revert("Invalid level");
        }

        uint256 requiredPayment;
        if (level == 1) {
            requiredPayment = 0.01 ether;
        } else if (level == 2) {
            requiredPayment = 0.05 ether;
        } else if (level == 3) {
            requiredPayment = 0.1 ether;
        }

        if (msg.value < requiredPayment) {
            revert("Insufficient payment");
        }

        members[msg.sender] = true;
        membershipLevel[msg.sender] = level;
        membershipExpiry[msg.sender] = block.timestamp + 365 days;
        joinTimestamp[msg.sender] = block.timestamp;
        memberPoints[msg.sender] = 0;

        if (level == 3) {
            premiumMembers[msg.sender] = true;
        } else {
            premiumMembers[msg.sender] = false;
        }

        totalMembers = totalMembers + 1;
        totalRevenue = totalRevenue + msg.value;

        emit MemberJoined(msg.sender, level);
    }

    function renewMembership() public payable {
        if (msg.sender == owner) {
            revert("Owner cannot be member");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[msg.sender] == false) {
            revert("Not a member");
        }

        uint256 level = membershipLevel[msg.sender];
        uint256 requiredPayment;
        if (level == 1) {
            requiredPayment = 0.01 ether;
        } else if (level == 2) {
            requiredPayment = 0.05 ether;
        } else if (level == 3) {
            requiredPayment = 0.1 ether;
        }

        if (msg.value < requiredPayment) {
            revert("Insufficient payment");
        }

        membershipExpiry[msg.sender] = membershipExpiry[msg.sender] + 365 days;
        totalRevenue = totalRevenue + msg.value;

        emit MembershipRenewed(msg.sender, membershipExpiry[msg.sender]);
    }

    function upgradeMembership(uint256 newLevel) public payable {
        if (msg.sender == owner) {
            revert("Owner cannot be member");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[msg.sender] == false) {
            revert("Not a member");
        }
        if (newLevel < 1 || newLevel > 3) {
            revert("Invalid level");
        }
        if (newLevel <= membershipLevel[msg.sender]) {
            revert("Cannot downgrade or same level");
        }

        uint256 currentLevel = membershipLevel[msg.sender];
        uint256 upgradeFee;

        if (currentLevel == 1 && newLevel == 2) {
            upgradeFee = 0.04 ether;
        } else if (currentLevel == 1 && newLevel == 3) {
            upgradeFee = 0.09 ether;
        } else if (currentLevel == 2 && newLevel == 3) {
            upgradeFee = 0.05 ether;
        }

        if (msg.value < upgradeFee) {
            revert("Insufficient upgrade fee");
        }

        membershipLevel[msg.sender] = newLevel;

        if (newLevel == 3) {
            premiumMembers[msg.sender] = true;
        } else {
            premiumMembers[msg.sender] = false;
        }

        totalRevenue = totalRevenue + msg.value;

        emit MemberUpgraded(msg.sender, newLevel);
    }

    function awardPoints(address member, uint256 points) public {
        if (msg.sender != owner) {
            revert("Only owner can award points");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[member] == false) {
            revert("Not a member");
        }
        if (points == 0) {
            revert("Points must be greater than 0");
        }

        memberPoints[member] = memberPoints[member] + points;

        emit PointsAwarded(member, points);
    }

    function checkMembershipStatus(address member) public view returns (bool, uint256, uint256, uint256, bool) {
        if (members[member] == false) {
            return (false, 0, 0, 0, false);
        }

        bool isActive = membershipExpiry[member] > block.timestamp;
        uint256 level = membershipLevel[member];
        uint256 expiry = membershipExpiry[member];
        uint256 points = memberPoints[member];
        bool isPremium = premiumMembers[member];

        return (isActive, level, expiry, points, isPremium);
    }

    function getMemberInfo(address member) public view returns (uint256, uint256, uint256, bool, uint256) {
        if (msg.sender != owner && msg.sender != member) {
            revert("Unauthorized access");
        }
        if (members[member] == false) {
            revert("Not a member");
        }

        uint256 level = membershipLevel[member];
        uint256 expiry = membershipExpiry[member];
        uint256 points = memberPoints[member];
        bool isPremium = premiumMembers[member];
        uint256 joinTime = joinTimestamp[member];

        return (level, expiry, points, isPremium, joinTime);
    }

    function deactivateContract() public {
        if (msg.sender != owner) {
            revert("Only owner can deactivate");
        }
        contractActive = false;
    }

    function activateContract() public {
        if (msg.sender != owner) {
            revert("Only owner can activate");
        }
        contractActive = true;
    }

    function withdrawFunds(uint256 amount) public {
        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }
        if (amount > address(this).balance) {
            revert("Insufficient balance");
        }

        payable(owner).transfer(amount);
    }

    function getContractStats() public view returns (uint256, uint256, bool) {
        if (msg.sender != owner) {
            revert("Only owner can view stats");
        }

        return (totalMembers, totalRevenue, contractActive);
    }

    function transferOwnership(address newOwner) public {
        if (msg.sender != owner) {
            revert("Only owner can transfer");
        }
        if (newOwner == address(0)) {
            revert("Invalid address");
        }

        owner = newOwner;
    }

    function bulkAwardPoints(address[] memory memberList, uint256 points) public {
        if (msg.sender != owner) {
            revert("Only owner can award points");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (points == 0) {
            revert("Points must be greater than 0");
        }

        for (uint256 i = 0; i < memberList.length; i++) {
            if (members[memberList[i]] == true) {
                memberPoints[memberList[i]] = memberPoints[memberList[i]] + points;
                emit PointsAwarded(memberList[i], points);
            }
        }
    }

    function checkMultipleMemberships(address[] memory memberList) public view returns (bool[] memory) {
        bool[] memory results = new bool[](memberList.length);

        for (uint256 i = 0; i < memberList.length; i++) {
            if (members[memberList[i]] == true && membershipExpiry[memberList[i]] > block.timestamp) {
                results[i] = true;
            } else {
                results[i] = false;
            }
        }

        return results;
    }

    receive() external payable {
        totalRevenue = totalRevenue + msg.value;
    }

    fallback() external payable {
        totalRevenue = totalRevenue + msg.value;
    }
}
