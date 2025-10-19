
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address owner;
    mapping(address => bool) members;
    mapping(address => uint256) membershipExpiry;
    mapping(address => uint256) membershipTier;
    mapping(address => uint256) memberPoints;
    mapping(address => bool) premiumMembers;
    mapping(address => uint256) joinDate;
    mapping(address => uint256) lastActivity;
    mapping(uint256 => uint256) tierPrices;
    uint256 totalMembers;
    uint256 totalRevenue;
    bool contractActive;

    event MemberJoined(address member, uint256 tier);
    event MembershipRenewed(address member, uint256 newExpiry);
    event PointsAwarded(address member, uint256 points);
    event TierUpgraded(address member, uint256 newTier);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        tierPrices[1] = 0.01 ether;
        tierPrices[2] = 0.05 ether;
        tierPrices[3] = 0.1 ether;
    }

    function joinMembership(uint256 tier) external payable {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (tier < 1 || tier > 3) {
            revert("Invalid tier");
        }
        if (msg.value < tierPrices[tier]) {
            revert("Insufficient payment");
        }
        if (members[msg.sender] == true) {
            revert("Already a member");
        }

        members[msg.sender] = true;
        membershipTier[msg.sender] = tier;
        joinDate[msg.sender] = block.timestamp;
        lastActivity[msg.sender] = block.timestamp;

        if (tier == 1) {
            membershipExpiry[msg.sender] = block.timestamp + 2592000;
            memberPoints[msg.sender] = 100;
        } else if (tier == 2) {
            membershipExpiry[msg.sender] = block.timestamp + 7776000;
            memberPoints[msg.sender] = 500;
            premiumMembers[msg.sender] = true;
        } else if (tier == 3) {
            membershipExpiry[msg.sender] = block.timestamp + 31536000;
            memberPoints[msg.sender] = 1000;
            premiumMembers[msg.sender] = true;
        }

        totalMembers++;
        totalRevenue += msg.value;

        emit MemberJoined(msg.sender, tier);
    }

    function renewMembership(uint256 tier) external payable {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (tier < 1 || tier > 3) {
            revert("Invalid tier");
        }
        if (msg.value < tierPrices[tier]) {
            revert("Insufficient payment");
        }
        if (members[msg.sender] == false) {
            revert("Not a member");
        }

        membershipTier[msg.sender] = tier;
        lastActivity[msg.sender] = block.timestamp;

        if (tier == 1) {
            membershipExpiry[msg.sender] = block.timestamp + 2592000;
        } else if (tier == 2) {
            membershipExpiry[msg.sender] = block.timestamp + 7776000;
            premiumMembers[msg.sender] = true;
        } else if (tier == 3) {
            membershipExpiry[msg.sender] = block.timestamp + 31536000;
            premiumMembers[msg.sender] = true;
        }

        totalRevenue += msg.value;

        emit MembershipRenewed(msg.sender, membershipExpiry[msg.sender]);
    }

    function upgradeTier(uint256 newTier) external payable {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (newTier < 1 || newTier > 3) {
            revert("Invalid tier");
        }
        if (members[msg.sender] == false) {
            revert("Not a member");
        }
        if (membershipExpiry[msg.sender] < block.timestamp) {
            revert("Membership expired");
        }
        if (newTier <= membershipTier[msg.sender]) {
            revert("Can only upgrade");
        }

        uint256 currentTier = membershipTier[msg.sender];
        uint256 upgradeCost = tierPrices[newTier] - tierPrices[currentTier];

        if (msg.value < upgradeCost) {
            revert("Insufficient payment");
        }

        membershipTier[msg.sender] = newTier;
        lastActivity[msg.sender] = block.timestamp;

        if (newTier == 2) {
            premiumMembers[msg.sender] = true;
            memberPoints[msg.sender] += 300;
        } else if (newTier == 3) {
            premiumMembers[msg.sender] = true;
            memberPoints[msg.sender] += 700;
        }

        totalRevenue += msg.value;

        emit TierUpgraded(msg.sender, newTier);
    }

    function awardPoints(address member, uint256 points) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }
        if (member == address(0)) {
            revert("Invalid address");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[member] == false) {
            revert("Not a member");
        }
        if (membershipExpiry[member] < block.timestamp) {
            revert("Membership expired");
        }

        memberPoints[member] += points;
        lastActivity[member] = block.timestamp;

        emit PointsAwarded(member, points);
    }

    function redeemPoints(uint256 points) external {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (contractActive == false) {
            revert("Contract not active");
        }
        if (members[msg.sender] == false) {
            revert("Not a member");
        }
        if (membershipExpiry[msg.sender] < block.timestamp) {
            revert("Membership expired");
        }
        if (memberPoints[msg.sender] < points) {
            revert("Insufficient points");
        }
        if (points < 100) {
            revert("Minimum 100 points");
        }

        memberPoints[msg.sender] -= points;
        lastActivity[msg.sender] = block.timestamp;

        uint256 rewardAmount = (points * 0.0001 ether) / 100;
        payable(msg.sender).transfer(rewardAmount);
    }

    function checkMembershipStatus(address member) external view returns (bool, uint256, uint256, uint256, bool) {
        if (member == address(0)) {
            revert("Invalid address");
        }

        return (
            members[member],
            membershipTier[member],
            membershipExpiry[member],
            memberPoints[member],
            premiumMembers[member]
        );
    }

    function getMemberActivity(address member) external view returns (uint256, uint256) {
        if (member == address(0)) {
            revert("Invalid address");
        }
        if (members[member] == false) {
            revert("Not a member");
        }

        return (joinDate[member], lastActivity[member]);
    }

    function updateTierPrice(uint256 tier, uint256 newPrice) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }
        if (tier < 1 || tier > 3) {
            revert("Invalid tier");
        }
        if (newPrice == 0) {
            revert("Price cannot be zero");
        }

        tierPrices[tier] = newPrice;
    }

    function getTierPrice(uint256 tier) external view returns (uint256) {
        if (tier < 1 || tier > 3) {
            revert("Invalid tier");
        }

        return tierPrices[tier];
    }

    function getContractStats() external view returns (uint256, uint256, bool) {
        if (msg.sender != owner) {
            revert("Only owner");
        }

        return (totalMembers, totalRevenue, contractActive);
    }

    function toggleContract() external {
        if (msg.sender != owner) {
            revert("Only owner");
        }

        contractActive = !contractActive;
    }

    function withdrawFunds(uint256 amount) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }
        if (amount > address(this).balance) {
            revert("Insufficient balance");
        }

        payable(owner).transfer(amount);
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }
        if (newOwner == address(0)) {
            revert("Invalid address");
        }

        owner = newOwner;
    }

    receive() external payable {}
}
