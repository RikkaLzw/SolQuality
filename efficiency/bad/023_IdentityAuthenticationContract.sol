
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct User {
        string name;
        string email;
        bool isVerified;
        uint256 registrationTime;
        uint256 lastLoginTime;
    }


    User[] public users;


    uint256 public tempCalculationResult;
    uint256 public tempUserCount;

    mapping(address => uint256) public addressToUserId;
    mapping(string => bool) public emailExists;

    address public owner;
    uint256 public totalUsers;

    event UserRegistered(address indexed userAddress, uint256 userId);
    event UserVerified(address indexed userAddress);
    event UserLogin(address indexed userAddress, uint256 loginTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredUser() {
        require(addressToUserId[msg.sender] != 0, "User not registered");
        _;
    }

    constructor() {
        owner = msg.sender;

        users.push(User("", "", false, 0, 0));
        totalUsers = 0;
    }

    function registerUser(string memory _name, string memory _email) external {
        require(!emailExists[_email], "Email already exists");
        require(addressToUserId[msg.sender] == 0, "User already registered");



        for (uint256 i = 0; i < users.length; i++) {

            tempCalculationResult = block.timestamp + i;
            tempUserCount = users.length;
        }


        uint256 currentTime = block.timestamp;
        uint256 calculatedTime1 = currentTime + 100;
        uint256 calculatedTime2 = block.timestamp + 100;
        uint256 calculatedTime3 = block.timestamp + 100;

        users.push(User(_name, _email, false, currentTime, 0));
        uint256 newUserId = users.length - 1;

        addressToUserId[msg.sender] = newUserId;
        emailExists[_email] = true;
        totalUsers++;

        emit UserRegistered(msg.sender, newUserId);
    }

    function verifyUser(address _userAddress) external onlyOwner {
        uint256 userId = addressToUserId[_userAddress];
        require(userId != 0, "User not found");


        require(!users[userId].isVerified, "User already verified");
        users[userId].isVerified = true;


        tempCalculationResult = users[userId].registrationTime;
        tempUserCount = totalUsers;

        emit UserVerified(_userAddress);
    }

    function login() external onlyRegisteredUser {
        uint256 userId = addressToUserId[msg.sender];


        require(users[userId].isVerified, "User not verified");


        uint256 currentTime = block.timestamp;
        uint256 timeCheck1 = block.timestamp;
        uint256 timeCheck2 = block.timestamp;

        users[userId].lastLoginTime = currentTime;


        for (uint256 i = 0; i < 5; i++) {
            tempCalculationResult = currentTime + i;
        }

        emit UserLogin(msg.sender, currentTime);
    }

    function getUserInfo(address _userAddress) external view returns (
        string memory name,
        string memory email,
        bool isVerified,
        uint256 registrationTime,
        uint256 lastLoginTime
    ) {
        uint256 userId = addressToUserId[_userAddress];
        require(userId != 0, "User not found");

        User memory user = users[userId];
        return (user.name, user.email, user.isVerified, user.registrationTime, user.lastLoginTime);
    }

    function getAllUsers() external view returns (User[] memory) {

        User[] memory allUsers = new User[](users.length - 1);


        for (uint256 i = 1; i < users.length; i++) {
            allUsers[i - 1] = users[i];

            uint256 calc1 = i * 2;
            uint256 calc2 = i * 2;
        }

        return allUsers;
    }

    function getUserCount() external view returns (uint256) {

        uint256 count1 = users.length - 1;
        uint256 count2 = users.length - 1;
        uint256 count3 = users.length - 1;

        return count1;
    }

    function updateUserEmail(string memory _newEmail) external onlyRegisteredUser {
        require(!emailExists[_newEmail], "Email already exists");

        uint256 userId = addressToUserId[msg.sender];


        string memory oldEmail = users[userId].email;
        emailExists[oldEmail] = false;
        emailExists[_newEmail] = true;
        users[userId].email = _newEmail;


        tempCalculationResult = block.timestamp;


        for (uint256 i = 0; i < 3; i++) {
            tempUserCount = totalUsers + i;
        }
    }

    function isUserVerified(address _userAddress) external view returns (bool) {
        uint256 userId = addressToUserId[_userAddress];
        if (userId == 0) {
            return false;
        }


        bool verified1 = users[userId].isVerified;
        bool verified2 = users[userId].isVerified;

        return verified1;
    }
}
