
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {


    address public owner;
    uint256 public totalUsers;
    uint256 public maxUsers;


    mapping(address => bool) public registeredUsers;
    mapping(address => string) public userNames;
    mapping(address => uint256) public userRegistrationTime;
    mapping(address => bool) public verifiedUsers;
    mapping(address => uint256) public userLevel;
    mapping(address => bool) public bannedUsers;
    mapping(address => uint256) public loginAttempts;
    mapping(address => uint256) public lastLoginTime;

    event UserRegistered(address indexed user, string name);
    event UserVerified(address indexed user);
    event UserBanned(address indexed user);
    event UserUnbanned(address indexed user);
    event LoginAttempt(address indexed user, bool success);

    constructor() {
        owner = msg.sender;
        totalUsers = 0;
        maxUsers = 10000;
    }


    function registerUser(string memory _name) public {

        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_name).length <= 50, "Name too long");
        require(!registeredUsers[msg.sender], "User already registered");
        require(totalUsers < maxUsers, "Maximum users reached");
        require(!bannedUsers[msg.sender], "User is banned");

        registeredUsers[msg.sender] = true;
        userNames[msg.sender] = _name;
        userRegistrationTime[msg.sender] = block.timestamp;
        verifiedUsers[msg.sender] = false;
        userLevel[msg.sender] = 1;
        loginAttempts[msg.sender] = 0;
        totalUsers++;

        emit UserRegistered(msg.sender, _name);
    }


    function verifyUser(address _user) public {
        require(msg.sender == owner, "Only owner can verify users");
        require(registeredUsers[_user], "User not registered");
        require(!verifiedUsers[_user], "User already verified");
        require(!bannedUsers[_user], "Cannot verify banned user");

        verifiedUsers[_user] = true;
        userLevel[_user] = 2;

        emit UserVerified(_user);
    }


    function banUser(address _user) public {
        require(msg.sender == owner, "Only owner can ban users");
        require(registeredUsers[_user], "User not registered");
        require(!bannedUsers[_user], "User already banned");

        bannedUsers[_user] = true;
        verifiedUsers[_user] = false;

        emit UserBanned(_user);
    }


    function unbanUser(address _user) public {
        require(msg.sender == owner, "Only owner can unban users");
        require(registeredUsers[_user], "User not registered");
        require(bannedUsers[_user], "User not banned");

        bannedUsers[_user] = false;

        emit UserUnbanned(_user);
    }


    function login() public returns (bool) {
        require(registeredUsers[msg.sender], "User not registered");
        require(!bannedUsers[msg.sender], "User is banned");
        require(loginAttempts[msg.sender] < 5, "Too many failed attempts");


        if (block.timestamp - lastLoginTime[msg.sender] < 3600) {
            loginAttempts[msg.sender]++;
            emit LoginAttempt(msg.sender, false);
            return false;
        }

        lastLoginTime[msg.sender] = block.timestamp;
        loginAttempts[msg.sender] = 0;

        emit LoginAttempt(msg.sender, true);
        return true;
    }


    function updateUserName(string memory _newName) public {
        require(bytes(_newName).length > 0, "Name cannot be empty");
        require(bytes(_newName).length <= 50, "Name too long");
        require(registeredUsers[msg.sender], "User not registered");
        require(!bannedUsers[msg.sender], "User is banned");
        require(verifiedUsers[msg.sender], "User not verified");

        userNames[msg.sender] = _newName;
    }


    function upgradeUserLevel(address _user) public {
        require(msg.sender == owner, "Only owner can upgrade users");
        require(registeredUsers[_user], "User not registered");
        require(verifiedUsers[_user], "User not verified");
        require(!bannedUsers[_user], "Cannot upgrade banned user");
        require(userLevel[_user] < 5, "Maximum level reached");

        userLevel[_user]++;
    }


    function resetLoginAttempts(address _user) public {
        require(msg.sender == owner, "Only owner can reset attempts");
        require(registeredUsers[_user], "User not registered");

        loginAttempts[_user] = 0;
    }


    function changeMaxUsers(uint256 _newMax) public {
        require(msg.sender == owner, "Only owner can change max users");
        require(_newMax > totalUsers, "New max must be greater than current users");
        require(_newMax <= 100000, "Max users too high");

        maxUsers = _newMax;
    }


    function getUserInfo(address _user) public returns (string memory, uint256, bool, uint256, bool, uint256) {

        require(registeredUsers[_user], "User not registered");

        return (
            userNames[_user],
            userRegistrationTime[_user],
            verifiedUsers[_user],
            userLevel[_user],
            bannedUsers[_user],
            loginAttempts[_user]
        );
    }


    function transferOwnership(address _newOwner) public {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != owner, "Same owner");

        owner = _newOwner;
    }


    function validateUserStatus(address _user) public view returns (bool) {

        if (!registeredUsers[_user]) return false;
        if (bannedUsers[_user]) return false;
        if (loginAttempts[_user] >= 5) return false;

        return true;
    }


    function emergencyBanAll() public {
        require(msg.sender == owner, "Only owner can emergency ban");



        totalUsers = 0;
    }


    function getContractStats() public view returns (uint256, uint256) {
        return (totalUsers, maxUsers);
    }
}
