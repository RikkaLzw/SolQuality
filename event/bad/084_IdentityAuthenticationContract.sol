
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct User {
        string username;
        bytes32 passwordHash;
        bool isActive;
        uint256 lastLoginTime;
        uint8 failedAttempts;
    }

    mapping(address => User) private users;
    mapping(string => address) private usernameToAddress;
    address public owner;
    uint8 public constant MAX_FAILED_ATTEMPTS = 3;
    uint256 public constant LOCKOUT_DURATION = 1 hours;

    event UserRegistered(string username, address userAddress);
    event LoginAttempt(address userAddress, bool success);
    event UserStatusChanged(address userAddress, bool status);

    error InvalidInput();
    error NotFound();
    error AccessDenied();
    error TooManyAttempts();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier userExists(address userAddress) {
        require(bytes(users[userAddress].username).length > 0);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerUser(string memory _username, string memory _password) external {
        require(bytes(_username).length > 0);
        require(bytes(_password).length >= 6);
        require(usernameToAddress[_username] == address(0));
        require(bytes(users[msg.sender].username).length == 0);

        bytes32 passwordHash = keccak256(abi.encodePacked(_password));

        users[msg.sender] = User({
            username: _username,
            passwordHash: passwordHash,
            isActive: true,
            lastLoginTime: 0,
            failedAttempts: 0
        });

        usernameToAddress[_username] = msg.sender;

        emit UserRegistered(_username, msg.sender);
    }

    function login(string memory _password) external userExists(msg.sender) {
        User storage user = users[msg.sender];

        require(user.isActive);

        if (user.failedAttempts >= MAX_FAILED_ATTEMPTS) {
            require(block.timestamp >= user.lastLoginTime + LOCKOUT_DURATION);
            user.failedAttempts = 0;
        }

        bytes32 passwordHash = keccak256(abi.encodePacked(_password));

        if (passwordHash == user.passwordHash) {
            user.lastLoginTime = block.timestamp;
            user.failedAttempts = 0;
            emit LoginAttempt(msg.sender, true);
        } else {
            user.failedAttempts++;
            user.lastLoginTime = block.timestamp;
            emit LoginAttempt(msg.sender, false);
            if (user.failedAttempts >= MAX_FAILED_ATTEMPTS) {
                revert TooManyAttempts();
            }
        }
    }

    function changePassword(string memory _oldPassword, string memory _newPassword) external userExists(msg.sender) {
        require(bytes(_newPassword).length >= 6);

        User storage user = users[msg.sender];
        require(user.isActive);

        bytes32 oldPasswordHash = keccak256(abi.encodePacked(_oldPassword));
        require(oldPasswordHash == user.passwordHash);

        user.passwordHash = keccak256(abi.encodePacked(_newPassword));
    }

    function deactivateUser(address _userAddress) external onlyOwner userExists(_userAddress) {
        users[_userAddress].isActive = false;
        emit UserStatusChanged(_userAddress, false);
    }

    function activateUser(address _userAddress) external onlyOwner userExists(_userAddress) {
        users[_userAddress].isActive = true;
        users[_userAddress].failedAttempts = 0;
        emit UserStatusChanged(_userAddress, true);
    }

    function resetFailedAttempts(address _userAddress) external onlyOwner userExists(_userAddress) {
        users[_userAddress].failedAttempts = 0;
    }

    function getUserInfo(address _userAddress) external view userExists(_userAddress) returns (string memory username, bool isActive, uint256 lastLoginTime, uint8 failedAttempts) {
        User memory user = users[_userAddress];
        return (user.username, user.isActive, user.lastLoginTime, user.failedAttempts);
    }

    function isUserActive(address _userAddress) external view returns (bool) {
        return users[_userAddress].isActive && bytes(users[_userAddress].username).length > 0;
    }

    function getUserByUsername(string memory _username) external view returns (address) {
        return usernameToAddress[_username];
    }

    function isUserLocked(address _userAddress) external view userExists(_userAddress) returns (bool) {
        User memory user = users[_userAddress];
        if (user.failedAttempts >= MAX_FAILED_ATTEMPTS) {
            return block.timestamp < user.lastLoginTime + LOCKOUT_DURATION;
        }
        return false;
    }
}
