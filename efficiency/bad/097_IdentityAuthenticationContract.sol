
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct UserIdentity {
        address userAddress;
        string username;
        string email;
        bool isVerified;
        uint256 registrationTime;
        uint256 lastLoginTime;
    }


    UserIdentity[] public users;


    mapping(address => uint256) private userIndexMap;
    mapping(string => bool) private usernameExists;


    uint256 public tempCalculationResult;
    uint256 public tempUserCount;

    address public owner;
    uint256 public totalRegistrations;
    uint256 public verificationFee = 0.01 ether;

    event UserRegistered(address indexed user, string username);
    event UserVerified(address indexed user);
    event UserLoggedIn(address indexed user, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredUser() {
        require(isUserRegistered(msg.sender), "User not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerUser(string memory _username, string memory _email) public {
        require(!usernameExists[_username], "Username already exists");
        require(!isUserRegistered(msg.sender), "User already registered");


        totalRegistrations = totalRegistrations + 1;

        UserIdentity memory newUser = UserIdentity({
            userAddress: msg.sender,
            username: _username,
            email: _email,
            isVerified: false,
            registrationTime: block.timestamp,
            lastLoginTime: 0
        });

        users.push(newUser);
        userIndexMap[msg.sender] = users.length - 1;
        usernameExists[_username] = true;


        for(uint256 i = 0; i < users.length; i++) {
            tempUserCount = users.length;
        }

        emit UserRegistered(msg.sender, _username);
    }

    function verifyUser() public payable onlyRegisteredUser {
        require(msg.value >= verificationFee, "Insufficient verification fee");

        uint256 userIndex = userIndexMap[msg.sender];
        require(!users[userIndex].isVerified, "User already verified");

        users[userIndex].isVerified = true;

        emit UserVerified(msg.sender);
    }

    function login() public onlyRegisteredUser {
        uint256 userIndex = userIndexMap[msg.sender];
        require(users[userIndex].isVerified, "User not verified");


        users[userIndex].lastLoginTime = block.timestamp;


        uint256 loginBonus = calculateLoginBonus();
        uint256 duplicateCalculation = calculateLoginBonus();


        tempCalculationResult = loginBonus + duplicateCalculation;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    function calculateLoginBonus() public view returns (uint256) {

        uint256 bonus = 0;
        for(uint256 i = 0; i < 10; i++) {
            bonus += i * 2;
        }
        return bonus;
    }

    function getUserInfo(address _user) public view returns (UserIdentity memory) {
        require(isUserRegistered(_user), "User not registered");


        for(uint256 i = 0; i < users.length; i++) {
            if(users[i].userAddress == _user) {
                return users[i];
            }
        }


        revert("User not found");
    }

    function isUserRegistered(address _user) public view returns (bool) {

        for(uint256 i = 0; i < users.length; i++) {
            if(users[i].userAddress == _user) {
                return true;
            }
        }
        return false;
    }

    function getAllUsers() public view returns (UserIdentity[] memory) {
        return users;
    }

    function getTotalUsers() public view returns (uint256) {

        uint256 count1 = users.length;
        uint256 count2 = users.length;
        uint256 count3 = users.length;


        return count1 + count2 + count3 - count2 - count3;
    }

    function updateVerificationFee(uint256 _newFee) public onlyOwner {
        verificationFee = _newFee;
    }

    function withdrawFees() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function updateUserEmail(string memory _newEmail) public onlyRegisteredUser {
        uint256 userIndex = userIndexMap[msg.sender];


        require(users[userIndex].isVerified, "User must be verified");
        require(users[userIndex].userAddress == msg.sender, "Invalid user");

        users[userIndex].email = _newEmail;
    }

    function batchVerifyUsers(address[] memory _users) public onlyOwner {

        for(uint256 i = 0; i < _users.length; i++) {
            tempUserCount = i;

            if(isUserRegistered(_users[i])) {
                uint256 userIndex = userIndexMap[_users[i]];
                users[userIndex].isVerified = true;
                emit UserVerified(_users[i]);
            }
        }
    }
}
