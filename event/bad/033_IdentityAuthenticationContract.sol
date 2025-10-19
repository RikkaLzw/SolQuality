
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct UserProfile {
        string username;
        bytes32 passwordHash;
        bool isActive;
        uint256 registrationTime;
        uint256 lastLoginTime;
    }

    mapping(address => UserProfile) private users;
    mapping(string => address) private usernameToAddress;
    address public owner;
    uint256 public totalUsers;

    error InvalidInput();
    error Unauthorized();
    error UserExists();
    error UserNotFound();

    event UserRegistered(address user, string username, uint256 timestamp);
    event UserLoggedIn(address user, uint256 timestamp);
    event UserDeactivated(address user);
    event OwnershipTransferred(address previousOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validUser() {
        require(users[msg.sender].isActive);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerUser(string memory _username, string memory _password) external {
        require(bytes(_username).length > 0);
        require(bytes(_password).length >= 6);
        require(users[msg.sender].registrationTime == 0);
        require(usernameToAddress[_username] == address(0));

        bytes32 passwordHash = keccak256(abi.encodePacked(_password, msg.sender));

        users[msg.sender] = UserProfile({
            username: _username,
            passwordHash: passwordHash,
            isActive: true,
            registrationTime: block.timestamp,
            lastLoginTime: 0
        });

        usernameToAddress[_username] = msg.sender;
        totalUsers++;

        emit UserRegistered(msg.sender, _username, block.timestamp);
    }

    function login(string memory _password) external validUser {
        bytes32 inputHash = keccak256(abi.encodePacked(_password, msg.sender));
        require(users[msg.sender].passwordHash == inputHash);

        users[msg.sender].lastLoginTime = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    function changePassword(string memory _oldPassword, string memory _newPassword) external validUser {
        require(bytes(_newPassword).length >= 6);

        bytes32 oldHash = keccak256(abi.encodePacked(_oldPassword, msg.sender));
        require(users[msg.sender].passwordHash == oldHash);

        bytes32 newHash = keccak256(abi.encodePacked(_newPassword, msg.sender));
        users[msg.sender].passwordHash = newHash;
    }

    function deactivateUser(address _user) external onlyOwner {
        require(users[_user].registrationTime != 0);

        users[_user].isActive = false;
        totalUsers--;

        emit UserDeactivated(_user);
    }

    function reactivateUser(address _user) external onlyOwner {
        require(users[_user].registrationTime != 0);
        require(!users[_user].isActive);

        users[_user].isActive = true;
        totalUsers++;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        address previousOwner = owner;
        owner = _newOwner;

        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function getUserProfile(address _user) external view returns (string memory username, bool isActive, uint256 registrationTime, uint256 lastLoginTime) {
        require(users[_user].registrationTime != 0);

        UserProfile memory profile = users[_user];
        return (profile.username, profile.isActive, profile.registrationTime, profile.lastLoginTime);
    }

    function isUserRegistered(address _user) external view returns (bool) {
        return users[_user].registrationTime != 0;
    }

    function getUserByUsername(string memory _username) external view returns (address) {
        return usernameToAddress[_username];
    }
}
