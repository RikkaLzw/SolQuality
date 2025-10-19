
pragma solidity ^0.8.0;

contract MembershipSystemContract {
    struct Member {
        uint256 id;
        address wallet;
        string name;
        string email;
        uint256 membershipLevel;
        uint256 joinDate;
        uint256 expiryDate;
        uint256 totalSpent;
        bool isActive;
        uint256 loyaltyPoints;
        string phoneNumber;
        string country;
    }

    mapping(address => Member) public members;
    mapping(uint256 => address) public memberIdToAddress;
    mapping(uint256 => uint256) public levelBenefits;

    uint256 public totalMembers;
    uint256 public nextMemberId = 1;
    address public owner;

    event MemberRegistered(address indexed member, uint256 memberId);
    event MembershipUpdated(address indexed member, uint256 newLevel);
    event PointsUpdated(address indexed member, uint256 newPoints);

    constructor() {
        owner = msg.sender;
        levelBenefits[1] = 5;
        levelBenefits[2] = 10;
        levelBenefits[3] = 15;
        levelBenefits[4] = 20;
        levelBenefits[5] = 25;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }





    function registerMemberAndProcessPaymentAndUpdateSystemStats(
        address memberAddress,
        string memory name,
        string memory email,
        string memory phoneNumber,
        string memory country,
        uint256 membershipLevel,
        uint256 paymentAmount,
        bool autoRenewal
    ) public {

        require(memberAddress != address(0), "Invalid address");
        require(members[memberAddress].id == 0, "Member already exists");
        require(membershipLevel > 0 && membershipLevel <= 5, "Invalid level");


        if (membershipLevel > 0) {
            if (membershipLevel <= 2) {
                if (paymentAmount >= 100) {
                    if (autoRenewal) {
                        if (bytes(name).length > 0) {
                            if (bytes(email).length > 0) {
                                members[memberAddress] = Member({
                                    id: nextMemberId,
                                    wallet: memberAddress,
                                    name: name,
                                    email: email,
                                    membershipLevel: membershipLevel,
                                    joinDate: block.timestamp,
                                    expiryDate: block.timestamp + 365 days,
                                    totalSpent: paymentAmount,
                                    isActive: true,
                                    loyaltyPoints: paymentAmount / 10,
                                    phoneNumber: phoneNumber,
                                    country: country
                                });
                            }
                        }
                    }
                }
            } else if (membershipLevel <= 4) {
                if (paymentAmount >= 500) {
                    if (autoRenewal) {
                        if (bytes(name).length > 0) {
                            members[memberAddress] = Member({
                                id: nextMemberId,
                                wallet: memberAddress,
                                name: name,
                                email: email,
                                membershipLevel: membershipLevel,
                                joinDate: block.timestamp,
                                expiryDate: block.timestamp + 365 days,
                                totalSpent: paymentAmount,
                                isActive: true,
                                loyaltyPoints: paymentAmount / 5,
                                phoneNumber: phoneNumber,
                                country: country
                            });
                        }
                    }
                }
            } else {
                if (paymentAmount >= 1000) {
                    members[memberAddress] = Member({
                        id: nextMemberId,
                        wallet: memberAddress,
                        name: name,
                        email: email,
                        membershipLevel: membershipLevel,
                        joinDate: block.timestamp,
                        expiryDate: block.timestamp + 365 days,
                        totalSpent: paymentAmount,
                        isActive: true,
                        loyaltyPoints: paymentAmount / 2,
                        phoneNumber: phoneNumber,
                        country: country
                    });
                }
            }
        }


        require(paymentAmount > 0, "Payment amount must be positive");


        memberIdToAddress[nextMemberId] = memberAddress;
        totalMembers++;
        nextMemberId++;

        emit MemberRegistered(memberAddress, members[memberAddress].id);
    }


    function calculateMembershipDiscount(address memberAddress) public view returns (uint256) {
        Member memory member = members[memberAddress];
        if (!member.isActive) return 0;

        uint256 discount = levelBenefits[member.membershipLevel];
        if (member.loyaltyPoints > 1000) {
            discount += 5;
        }
        return discount;
    }


    function validateMembershipLevel(uint256 level) public pure returns (bool) {
        return level > 0 && level <= 5;
    }



    function updateMemberAndProcessLoyaltyAndSendNotification(
        address memberAddress,
        uint256 newLevel,
        uint256 additionalPoints,
        string memory notificationMessage
    ) public onlyOwner {

        require(members[memberAddress].id != 0, "Member does not exist");
        require(newLevel > 0 && newLevel <= 5, "Invalid level");

        members[memberAddress].membershipLevel = newLevel;


        members[memberAddress].loyaltyPoints += additionalPoints;


        if (bytes(notificationMessage).length > 0) {

        }

        emit MembershipUpdated(memberAddress, newLevel);
        emit PointsUpdated(memberAddress, members[memberAddress].loyaltyPoints);
    }



    function processComplexMemberOperation(
        address memberAddress,
        uint256 operation,
        uint256 value1,
        uint256 value2,
        string memory stringParam1,
        string memory stringParam2,
        bool boolParam
    ) public {
        require(members[memberAddress].id != 0, "Member does not exist");


        if (operation == 1) {
            if (value1 > 0) {
                if (value2 > value1) {
                    if (boolParam) {
                        if (bytes(stringParam1).length > 0) {
                            if (bytes(stringParam2).length > 0) {
                                members[memberAddress].totalSpent += value1;
                                members[memberAddress].loyaltyPoints += value1 / 10;
                            } else {
                                members[memberAddress].totalSpent += value2;
                            }
                        } else {
                            if (value1 > 100) {
                                members[memberAddress].loyaltyPoints += value2;
                            }
                        }
                    } else {
                        if (value2 > 500) {
                            members[memberAddress].membershipLevel = (members[memberAddress].membershipLevel % 5) + 1;
                        }
                    }
                }
            }
        } else if (operation == 2) {
            if (boolParam && value1 > value2) {
                if (members[memberAddress].loyaltyPoints > 1000) {
                    members[memberAddress].expiryDate += value1 * 86400;
                }
            }
        }
    }

    function getMemberInfo(address memberAddress) public view returns (
        uint256 id,
        string memory name,
        uint256 level,
        uint256 points,
        bool active
    ) {
        Member memory member = members[memberAddress];
        return (
            member.id,
            member.name,
            member.membershipLevel,
            member.loyaltyPoints,
            member.isActive
        );
    }

    function renewMembership(address memberAddress) public {
        require(members[memberAddress].id != 0, "Member does not exist");
        members[memberAddress].expiryDate = block.timestamp + 365 days;
        members[memberAddress].isActive = true;
    }

    function deactivateMember(address memberAddress) public onlyOwner {
        require(members[memberAddress].id != 0, "Member does not exist");
        members[memberAddress].isActive = false;
    }

    function getTotalMembers() public view returns (uint256) {
        return totalMembers;
    }
}
