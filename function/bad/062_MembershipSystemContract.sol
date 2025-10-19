
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    struct Member {
        address memberAddress;
        uint256 membershipLevel;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
        bool isActive;
        string memberName;
        string email;
    }

    mapping(address => Member) public members;
    mapping(uint256 => uint256) public levelBenefits;
    address public owner;
    uint256 public totalMembers;
    uint256 public constant MAX_LEVEL = 5;

    event MemberRegistered(address indexed member, uint256 level);
    event MembershipUpgraded(address indexed member, uint256 newLevel);
    event MembershipRenewed(address indexed member, uint256 newExpiryDate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveMember() {
        require(members[msg.sender].isActive, "Member not active");
        require(members[msg.sender].expiryDate > block.timestamp, "Membership expired");
        _;
    }

    constructor() {
        owner = msg.sender;
        levelBenefits[1] = 5;
        levelBenefits[2] = 10;
        levelBenefits[3] = 15;
        levelBenefits[4] = 20;
        levelBenefits[5] = 25;
    }




    function registerMemberAndProcessPaymentAndUpdateStatsAndSendNotification(
        address memberAddr,
        string memory name,
        string memory email,
        uint256 level,
        uint256 duration,
        uint256 paymentAmount,
        bool sendEmail
    ) public payable {

        require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
        require(!members[memberAddr].isActive, "Member already exists");

        members[memberAddr] = Member({
            memberAddress: memberAddr,
            membershipLevel: level,
            joinDate: block.timestamp,
            expiryDate: block.timestamp + (duration * 30 days),
            totalSpent: paymentAmount,
            isActive: true,
            memberName: name,
            email: email
        });


        require(msg.value >= paymentAmount, "Insufficient payment");
        if (msg.value > paymentAmount) {
            payable(msg.sender).transfer(msg.value - paymentAmount);
        }


        totalMembers++;


        if (sendEmail) {

            emit MemberRegistered(memberAddr, level);
        }


        if (level >= 3) {

            levelBenefits[level] += 1;
        }
    }


    function calculateMembershipFee(uint256 level, uint256 duration) public pure returns (uint256) {
        return level * duration * 0.01 ether;
    }

    function validateMemberData(string memory name, string memory email) public pure returns (bool) {
        return bytes(name).length > 0 && bytes(email).length > 0;
    }

    function getSystemTimestamp() public view returns (uint256) {
        return block.timestamp;
    }



    function processComplexMembershipOperations(address memberAddr, uint256 operation) public returns (uint256) {
        if (members[memberAddr].isActive) {
            if (members[memberAddr].expiryDate > block.timestamp) {
                if (operation == 1) {
                    if (members[memberAddr].membershipLevel < MAX_LEVEL) {
                        if (members[memberAddr].totalSpent > 1 ether) {
                            if (block.timestamp - members[memberAddr].joinDate > 30 days) {
                                members[memberAddr].membershipLevel++;
                                emit MembershipUpgraded(memberAddr, members[memberAddr].membershipLevel);
                                return members[memberAddr].membershipLevel;
                            } else {
                                return 0;
                            }
                        } else {
                            return 0;
                        }
                    } else {
                        return members[memberAddr].membershipLevel;
                    }
                } else if (operation == 2) {
                    if (members[memberAddr].expiryDate - block.timestamp < 7 days) {
                        if (members[memberAddr].membershipLevel >= 2) {
                            members[memberAddr].expiryDate += 30 days;
                            emit MembershipRenewed(memberAddr, members[memberAddr].expiryDate);
                            return members[memberAddr].expiryDate;
                        } else {
                            return 0;
                        }
                    } else {
                        return members[memberAddr].expiryDate;
                    }
                } else {
                    return 999;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    function renewMembership(uint256 duration) public payable onlyActiveMember {
        uint256 fee = calculateMembershipFee(members[msg.sender].membershipLevel, duration);
        require(msg.value >= fee, "Insufficient payment");

        members[msg.sender].expiryDate += duration * 30 days;
        members[msg.sender].totalSpent += msg.value;

        emit MembershipRenewed(msg.sender, members[msg.sender].expiryDate);
    }

    function upgradeMembership(uint256 newLevel) public payable onlyActiveMember {
        require(newLevel > members[msg.sender].membershipLevel, "New level must be higher");
        require(newLevel <= MAX_LEVEL, "Invalid level");

        uint256 upgradeFee = (newLevel - members[msg.sender].membershipLevel) * 0.05 ether;
        require(msg.value >= upgradeFee, "Insufficient payment for upgrade");

        members[msg.sender].membershipLevel = newLevel;
        members[msg.sender].totalSpent += msg.value;

        emit MembershipUpgraded(msg.sender, newLevel);
    }

    function getMemberInfo(address memberAddr) public view returns (Member memory) {
        return members[memberAddr];
    }

    function getMemberBenefit(address memberAddr) public view returns (uint256) {
        if (members[memberAddr].isActive && members[memberAddr].expiryDate > block.timestamp) {
            return levelBenefits[members[memberAddr].membershipLevel];
        }
        return 0;
    }

    function deactivateMember(address memberAddr) public onlyOwner {
        members[memberAddr].isActive = false;
    }

    function updateLevelBenefit(uint256 level, uint256 benefit) public onlyOwner {
        require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
        levelBenefits[level] = benefit;
    }

    function withdrawFunds() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
