
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    address owner;
    mapping(address => bool) members;
    mapping(address => uint256) membershipExpiry;
    mapping(address => uint256) membershipLevel;
    mapping(address => uint256) totalSpent;
    mapping(address => bool) premiumMembers;
    mapping(address => uint256) joinDate;
    mapping(address => uint256) lastActivity;
    uint256 totalMembers;
    uint256 totalRevenue;
    bool contractActive;

    event MemberJoined(address member, uint256 level);
    event MembershipRenewed(address member, uint256 newExpiry);
    event MemberUpgraded(address member, uint256 newLevel);
    event PaymentReceived(address member, uint256 amount);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        totalMembers = 0;
        totalRevenue = 0;
    }

    function joinMembership(uint256 level) public payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }


        if (level == 1) {
            if (msg.value < 100000000000000000) {
                revert("Insufficient payment for basic membership");
            }
        } else if (level == 2) {
            if (msg.value < 500000000000000000) {
                revert("Insufficient payment for premium membership");
            }
        } else if (level == 3) {
            if (msg.value < 1000000000000000000) {
                revert("Insufficient payment for VIP membership");
            }
        } else {
            revert("Invalid membership level");
        }

        members[msg.sender] = true;
        membershipLevel[msg.sender] = level;
        membershipExpiry[msg.sender] = block.timestamp + 31536000;
        joinDate[msg.sender] = block.timestamp;
        lastActivity[msg.sender] = block.timestamp;
        totalSpent[msg.sender] += msg.value;
        totalMembers += 1;
        totalRevenue += msg.value;

        if (level >= 2) {
            premiumMembers[msg.sender] = true;
        }

        emit MemberJoined(msg.sender, level);
        emit PaymentReceived(msg.sender, msg.value);
    }

    function renewMembership() public payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (!members[msg.sender]) {
            revert("Not a member");
        }

        uint256 level = membershipLevel[msg.sender];


        if (level == 1) {
            if (msg.value < 100000000000000000) {
                revert("Insufficient payment for basic membership");
            }
        } else if (level == 2) {
            if (msg.value < 500000000000000000) {
                revert("Insufficient payment for premium membership");
            }
        } else if (level == 3) {
            if (msg.value < 1000000000000000000) {
                revert("Insufficient payment for VIP membership");
            }
        }

        membershipExpiry[msg.sender] = block.timestamp + 31536000;
        lastActivity[msg.sender] = block.timestamp;
        totalSpent[msg.sender] += msg.value;
        totalRevenue += msg.value;

        emit MembershipRenewed(msg.sender, membershipExpiry[msg.sender]);
        emit PaymentReceived(msg.sender, msg.value);
    }

    function upgradeMembership(uint256 newLevel) public payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (!members[msg.sender]) {
            revert("Not a member");
        }

        if (newLevel <= membershipLevel[msg.sender]) {
            revert("Can only upgrade to higher level");
        }

        if (block.timestamp > membershipExpiry[msg.sender]) {
            revert("Membership expired");
        }


        if (newLevel == 2) {
            if (membershipLevel[msg.sender] == 1) {
                if (msg.value < 400000000000000000) {
                    revert("Insufficient payment for upgrade");
                }
            }
        } else if (newLevel == 3) {
            if (membershipLevel[msg.sender] == 1) {
                if (msg.value < 900000000000000000) {
                    revert("Insufficient payment for upgrade");
                }
            } else if (membershipLevel[msg.sender] == 2) {
                if (msg.value < 500000000000000000) {
                    revert("Insufficient payment for upgrade");
                }
            }
        }

        membershipLevel[msg.sender] = newLevel;
        lastActivity[msg.sender] = block.timestamp;
        totalSpent[msg.sender] += msg.value;
        totalRevenue += msg.value;

        if (newLevel >= 2) {
            premiumMembers[msg.sender] = true;
        }

        emit MemberUpgraded(msg.sender, newLevel);
        emit PaymentReceived(msg.sender, msg.value);
    }

    function accessPremiumFeature() public {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (!members[msg.sender]) {
            revert("Not a member");
        }

        if (block.timestamp > membershipExpiry[msg.sender]) {
            revert("Membership expired");
        }

        if (membershipLevel[msg.sender] < 2) {
            revert("Premium membership required");
        }

        lastActivity[msg.sender] = block.timestamp;

    }

    function accessVIPFeature() public {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (!members[msg.sender]) {
            revert("Not a member");
        }

        if (block.timestamp > membershipExpiry[msg.sender]) {
            revert("Membership expired");
        }

        if (membershipLevel[msg.sender] < 3) {
            revert("VIP membership required");
        }

        lastActivity[msg.sender] = block.timestamp;

    }

    function getMemberInfo(address member) public view returns (bool, uint256, uint256, uint256, uint256) {
        return (
            members[member],
            membershipLevel[member],
            membershipExpiry[member],
            totalSpent[member],
            joinDate[member]
        );
    }

    function checkMembershipStatus(address member) public view returns (bool) {
        if (!members[member]) {
            return false;
        }
        if (block.timestamp > membershipExpiry[member]) {
            return false;
        }
        return true;
    }

    function withdrawFunds(uint256 amount) public {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (amount > address(this).balance) {
            revert("Insufficient contract balance");
        }

        payable(owner).transfer(amount);
    }

    function setContractStatus(bool status) public {

        if (msg.sender != owner) {
            revert("Only owner can change status");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        contractActive = status;
    }

    function transferOwnership(address newOwner) public {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }

    function getContractStats() public view returns (uint256, uint256, bool) {
        return (totalMembers, totalRevenue, contractActive);
    }

    function bulkAddMembers(address[] memory newMembers, uint256[] memory levels) public payable {

        if (msg.sender != owner) {
            revert("Only owner can bulk add");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (newMembers.length != levels.length) {
            revert("Arrays length mismatch");
        }

        for (uint256 i = 0; i < newMembers.length; i++) {
            if (newMembers[i] == address(0)) {
                continue;
            }

            members[newMembers[i]] = true;
            membershipLevel[newMembers[i]] = levels[i];
            membershipExpiry[newMembers[i]] = block.timestamp + 31536000;
            joinDate[newMembers[i]] = block.timestamp;
            lastActivity[newMembers[i]] = block.timestamp;
            totalMembers += 1;

            if (levels[i] >= 2) {
                premiumMembers[newMembers[i]] = true;
            }

            emit MemberJoined(newMembers[i], levels[i]);
        }
    }

    function extendMembership(address member, uint256 additionalTime) public {

        if (msg.sender != owner) {
            revert("Only owner can extend membership");
        }
        if (owner == address(0)) {
            revert("Owner not set");
        }

        if (!members[member]) {
            revert("Not a member");
        }

        membershipExpiry[member] += additionalTime;
        emit MembershipRenewed(member, membershipExpiry[member]);
    }

    receive() external payable {
        totalRevenue += msg.value;
    }

    fallback() external payable {
        totalRevenue += msg.value;
    }
}
