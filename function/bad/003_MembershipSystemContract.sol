
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    struct Member {
        address memberAddress;
        string name;
        uint256 membershipLevel;
        uint256 joinDate;
        uint256 expiryDate;
        bool isActive;
        uint256 totalSpent;
        uint256 rewardPoints;
    }

    mapping(address => Member) public members;
    mapping(uint256 => address) public memberIdToAddress;
    mapping(address => bool) public isMember;

    address public owner;
    uint256 public totalMembers;
    uint256 public nextMemberId;

    event MemberRegistered(address indexed member, uint256 memberId);
    event MembershipUpdated(address indexed member, uint256 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextMemberId = 1;
    }




    function registerMemberAndUpdateSystemAndCalculateRewards(
        address memberAddr,
        string memory memberName,
        uint256 initialLevel,
        uint256 membershipDuration,
        uint256 initialSpending,
        bool autoRenewal,
        string memory referralCode
    ) public {

        require(!isMember[memberAddr], "Already a member");
        require(memberAddr != address(0), "Invalid address");

        Member storage newMember = members[memberAddr];
        newMember.memberAddress = memberAddr;
        newMember.name = memberName;
        newMember.membershipLevel = initialLevel;
        newMember.joinDate = block.timestamp;
        newMember.expiryDate = block.timestamp + membershipDuration;
        newMember.isActive = true;
        newMember.totalSpent = initialSpending;


        if (initialSpending > 1000) {
            newMember.rewardPoints = initialSpending * 2;
        } else if (initialSpending > 500) {
            newMember.rewardPoints = initialSpending + 100;
        } else {
            newMember.rewardPoints = initialSpending / 2;
        }


        isMember[memberAddr] = true;
        memberIdToAddress[nextMemberId] = memberAddr;
        totalMembers++;
        nextMemberId++;


        if (bytes(referralCode).length > 0) {

            newMember.rewardPoints += 50;
        }


        if (autoRenewal && initialLevel >= 2) {
            newMember.expiryDate += 365 days;
        }

        emit MemberRegistered(memberAddr, nextMemberId - 1);
    }


    function calculateMembershipFee(uint256 level, uint256 duration) public pure returns (uint256) {
        return level * duration * 100;
    }

    function validateMembershipLevel(uint256 level) public pure returns (bool) {
        return level >= 1 && level <= 5;
    }



    function processComplexMembershipOperation(address memberAddr, uint256 operationType) public returns (bool, uint256, string memory) {
        require(isMember[memberAddr], "Not a member");

        Member storage member = members[memberAddr];

        if (operationType == 1) {

            if (member.membershipLevel < 5) {
                if (member.totalSpent > 5000) {
                    if (member.rewardPoints > 1000) {
                        if (block.timestamp < member.expiryDate) {
                            if (member.isActive) {
                                member.membershipLevel++;
                                member.rewardPoints -= 500;
                                return (true, member.membershipLevel, "Level upgraded successfully");
                            } else {
                                return (false, 0, "Member not active");
                            }
                        } else {
                            return (false, 0, "Membership expired");
                        }
                    } else {
                        return (false, 0, "Insufficient reward points");
                    }
                } else {
                    return (false, 0, "Insufficient spending");
                }
            } else {
                return (false, 0, "Already at max level");
            }
        } else if (operationType == 2) {

            if (member.isActive) {
                if (member.membershipLevel >= 2) {
                    if (member.rewardPoints >= 200) {
                        member.expiryDate += 365 days;
                        member.rewardPoints -= 200;
                        return (true, member.expiryDate, "Membership renewed");
                    } else {
                        if (member.totalSpent > 2000) {
                            member.expiryDate += 180 days;
                            return (true, member.expiryDate, "Partial renewal");
                        } else {
                            return (false, 0, "Cannot renew");
                        }
                    }
                } else {
                    return (false, 0, "Level too low for renewal");
                }
            } else {
                return (false, 0, "Member not active");
            }
        } else if (operationType == 3) {

            if (member.rewardPoints > 0) {
                if (member.rewardPoints >= 1000) {
                    if (member.membershipLevel >= 3) {
                        member.rewardPoints -= 1000;
                        member.totalSpent += 100;
                        return (true, member.rewardPoints, "Points redeemed for spending credit");
                    } else {
                        if (member.rewardPoints >= 500) {
                            member.rewardPoints -= 500;
                            return (true, member.rewardPoints, "Partial redemption");
                        } else {
                            return (false, 0, "Insufficient points for partial redemption");
                        }
                    }
                } else {
                    return (false, 0, "Insufficient points");
                }
            } else {
                return (false, 0, "No points available");
            }
        } else {
            return (false, 0, "Invalid operation type");
        }
    }

    function getMemberInfo(address memberAddr) public view returns (Member memory) {
        require(isMember[memberAddr], "Not a member");
        return members[memberAddr];
    }

    function updateMemberSpending(address memberAddr, uint256 amount) public onlyOwner {
        require(isMember[memberAddr], "Not a member");
        members[memberAddr].totalSpent += amount;
        members[memberAddr].rewardPoints += amount / 10;
    }

    function deactivateMember(address memberAddr) public onlyOwner {
        require(isMember[memberAddr], "Not a member");
        members[memberAddr].isActive = false;
    }

    function reactivateMember(address memberAddr) public onlyOwner {
        require(isMember[memberAddr], "Not a member");
        require(!members[memberAddr].isActive, "Already active");
        members[memberAddr].isActive = true;
    }
}
