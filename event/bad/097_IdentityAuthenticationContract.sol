
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct User {
        string username;
        bytes32 passwordHash;
        bool isActive;
        uint256 registrationTime;
        uint256 lastLoginTime;
    }

    mapping(address => User) private users;
    mapping(string => address) private usernameToAddress;
    mapping(address => bool) private registeredUsers;

    address public owner;
    uint256 public totalUsers;


    event UserRegistered(address userAddress, string username, uint256 timestamp);
    event UserLoggedIn(address userAddress, uint256 timestamp);
    event UserDeactivated(address userAddress);
    event PasswordChanged(address userAddress);


    error InvalidInput();
    error NotFound();
    error AccessDenied();
    error AlreadyExists();

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
        totalUsers = 0;
    }

    function registerUser(string memory _username, string memory _password) external {

        require(bytes(_username).length > 0);
        require(bytes(_password).length >= 6);
        require(!registeredUsers[msg.sender]);
        require(usernameToAddress[_username] == address(0));

        bytes32 passwordHash = keccak256(abi.encodePacked(_password, msg.sender));

        users[msg.sender] = User({
            username: _username,
            passwordHash: passwordHash,
            isActive: true,
            registrationTime: block.timestamp,
            lastLoginTime: 0
        });

        usernameToAddress[_username] = msg.sender;
        registeredUsers[msg.sender] = true;
        totalUsers++;

        emit UserRegistered(msg.sender, _username, block.timestamp);
    }

    function login(string memory _password) external onlyRegisteredUser {
        bytes32 inputPasswordHash = keccak256(abi.encodePacked(_password, msg.sender));

        require(users[msg.sender].passwordHash == inputPasswordHash);
        require(users[msg.sender].isActive);


        users[msg.sender].lastLoginTime = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    function changePassword(string memory _oldPassword, string memory _newPassword) external onlyRegisteredUser {
        bytes32 oldPasswordHash = keccak256(abi.encodePacked(_oldPassword, msg.sender));

        require(users[msg.sender].passwordHash == oldPasswordHash);
        require(bytes(_newPassword).length >= 6);

        bytes32 newPasswordHash = keccak256(abi.encodePacked(_newPassword, msg.sender));

        users[msg.sender].passwordHash = newPasswordHash;

        emit PasswordChanged(msg.sender);
    }

    function deactivateUser(address _userAddress) external onlyOwner {

        require(registeredUsers[_userAddress]);
        require(users[_userAddress].isActive);


        users[_userAddress].isActive = false;

        emit UserDeactivated(_userAddress);
    }

    function reactivateUser(address _userAddress) external onlyOwner {

        require(registeredUsers[_userAddress]);
        require(!users[_userAddress].isActive);


        users[_userAddress].isActive = true;
    }

    function updateUsername(string memory _newUsername) external onlyRegisteredUser {

        require(bytes(_newUsername).length > 0);
        require(usernameToAddress[_newUsername] == address(0));

        string memory oldUsername = users[msg.sender].username;


        delete usernameToAddress[oldUsername];
        usernameToAddress[_newUsername] = msg.sender;
        users[msg.sender].username = _newUsername;
    }

    function getUserInfo(address _userAddress) external view returns (
        string memory username,
        bool isActive,
        uint256 registrationTime,
        uint256 lastLoginTime
    ) {

        require(registeredUsers[_userAddress]);

        User memory user = users[_userAddress];
        return (user.username, user.isActive, user.registrationTime, user.lastLoginTime);
    }

    function isUserRegistered(address _userAddress) external view returns (bool) {
        return registeredUsers[_userAddress];
    }

    function isUserActive(address _userAddress) external view returns (bool) {

        require(registeredUsers[_userAddress]);
        return users[_userAddress].isActive;
    }

    function getUsernameByAddress(address _userAddress) external view returns (string memory) {

        require(registeredUsers[_userAddress]);
        return users[_userAddress].username;
    }

    function getAddressByUsername(string memory _username) external view returns (address) {
        address userAddress = usernameToAddress[_username];

        require(userAddress != address(0));
        return userAddress;
    }

    function verifyPassword(string memory _password) external view onlyRegisteredUser returns (bool) {
        bytes32 inputPasswordHash = keccak256(abi.encodePacked(_password, msg.sender));
        return users[msg.sender].passwordHash == inputPasswordHash;
    }


    function emergencyStop() external onlyOwner {
        require(false);
    }
}
