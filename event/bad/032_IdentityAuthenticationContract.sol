
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
    mapping(address => bool) public registeredUsers;

    address public owner;
    uint256 public totalUsers;


    event UserRegistered(address user, string username);
    event UserLoggedIn(address user, uint256 timestamp);
    event UserDeactivated(address user);
    event PasswordChanged(address user);


    error Bad();
    error Invalid();
    error NotFound();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyRegisteredUser() {
        require(registeredUsers[msg.sender]);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerUser(string memory _username, string memory _password) external {
        require(bytes(_username).length > 0);
        require(bytes(_password).length >= 6);
        require(!registeredUsers[msg.sender]);
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
        registeredUsers[msg.sender] = true;
        totalUsers++;

        emit UserRegistered(msg.sender, _username);
    }

    function login(string memory _password) external onlyRegisteredUser {
        bytes32 passwordHash = keccak256(abi.encodePacked(_password, msg.sender));
        require(users[msg.sender].passwordHash == passwordHash);
        require(users[msg.sender].isActive);

        users[msg.sender].lastLoginTime = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    function changePassword(string memory _oldPassword, string memory _newPassword) external onlyRegisteredUser {
        require(bytes(_newPassword).length >= 6);

        bytes32 oldPasswordHash = keccak256(abi.encodePacked(_oldPassword, msg.sender));
        if (users[msg.sender].passwordHash != oldPasswordHash) {
            revert Invalid();
        }

        bytes32 newPasswordHash = keccak256(abi.encodePacked(_newPassword, msg.sender));
        users[msg.sender].passwordHash = newPasswordHash;

        emit PasswordChanged(msg.sender);
    }

    function deactivateUser(address _user) external onlyOwner {
        if (!registeredUsers[_user]) {
            revert NotFound();
        }

        users[_user].isActive = false;
        emit UserDeactivated(_user);
    }

    function reactivateUser(address _user) external onlyOwner {
        require(registeredUsers[_user]);
        users[_user].isActive = true;
    }

    function getUserProfile(address _user) external view returns (string memory username, bool isActive, uint256 registrationTime, uint256 lastLoginTime) {
        if (!registeredUsers[_user]) {
            revert Bad();
        }

        UserProfile memory profile = users[_user];
        return (profile.username, profile.isActive, profile.registrationTime, profile.lastLoginTime);
    }

    function isUserActive(address _user) external view returns (bool) {
        require(registeredUsers[_user]);
        return users[_user].isActive;
    }

    function getAddressByUsername(string memory _username) external view returns (address) {
        address userAddress = usernameToAddress[_username];
        require(userAddress != address(0));
        return userAddress;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }
}
