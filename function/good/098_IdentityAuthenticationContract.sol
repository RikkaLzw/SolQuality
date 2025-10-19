
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct Identity {
        string name;
        string email;
        bytes32 passwordHash;
        bool isVerified;
        bool isActive;
        uint256 createdAt;
        uint256 lastLogin;
    }

    mapping(address => Identity) private identities;
    mapping(string => address) private emailToAddress;
    mapping(address => bool) private registeredUsers;

    address private owner;
    uint256 private totalUsers;

    event UserRegistered(address indexed user, string email);
    event UserVerified(address indexed user);
    event UserLoggedIn(address indexed user, uint256 timestamp);
    event UserDeactivated(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegistered() {
        require(registeredUsers[msg.sender], "User not registered");
        _;
    }

    modifier onlyVerified() {
        require(identities[msg.sender].isVerified, "User not verified");
        _;
    }

    modifier onlyActive() {
        require(identities[msg.sender].isActive, "User account deactivated");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalUsers = 0;
    }

    function registerUser(
        string memory _name,
        string memory _email,
        bytes32 _passwordHash
    ) public returns (bool) {
        require(!registeredUsers[msg.sender], "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(emailToAddress[_email] == address(0), "Email already exists");

        identities[msg.sender] = Identity({
            name: _name,
            email: _email,
            passwordHash: _passwordHash,
            isVerified: false,
            isActive: true,
            createdAt: block.timestamp,
            lastLogin: 0
        });

        registeredUsers[msg.sender] = true;
        emailToAddress[_email] = msg.sender;
        totalUsers++;

        emit UserRegistered(msg.sender, _email);
        return true;
    }

    function verifyUser(address _userAddress) public onlyOwner returns (bool) {
        require(registeredUsers[_userAddress], "User not registered");
        require(!identities[_userAddress].isVerified, "User already verified");

        identities[_userAddress].isVerified = true;

        emit UserVerified(_userAddress);
        return true;
    }

    function authenticate(bytes32 _passwordHash) public onlyRegistered onlyVerified onlyActive returns (bool) {
        require(identities[msg.sender].passwordHash == _passwordHash, "Invalid password");

        identities[msg.sender].lastLogin = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
        return true;
    }

    function updatePassword(
        bytes32 _oldPasswordHash,
        bytes32 _newPasswordHash
    ) public onlyRegistered onlyVerified onlyActive returns (bool) {
        require(identities[msg.sender].passwordHash == _oldPasswordHash, "Invalid old password");
        require(_newPasswordHash != _oldPasswordHash, "New password must be different");

        identities[msg.sender].passwordHash = _newPasswordHash;
        return true;
    }

    function deactivateUser(address _userAddress) public onlyOwner returns (bool) {
        require(registeredUsers[_userAddress], "User not registered");
        require(identities[_userAddress].isActive, "User already deactivated");

        identities[_userAddress].isActive = false;

        emit UserDeactivated(_userAddress);
        return true;
    }

    function getUserInfo(address _userAddress) public view returns (
        string memory name,
        string memory email,
        bool isVerified,
        bool isActive
    ) {
        require(registeredUsers[_userAddress], "User not registered");
        require(msg.sender == _userAddress || msg.sender == owner, "Access denied");

        Identity memory user = identities[_userAddress];
        return (user.name, user.email, user.isVerified, user.isActive);
    }

    function isUserRegistered(address _userAddress) public view returns (bool) {
        return registeredUsers[_userAddress];
    }

    function isUserVerified(address _userAddress) public view returns (bool) {
        return registeredUsers[_userAddress] && identities[_userAddress].isVerified;
    }

    function isUserActive(address _userAddress) public view returns (bool) {
        return registeredUsers[_userAddress] && identities[_userAddress].isActive;
    }

    function getTotalUsers() public view returns (uint256) {
        return totalUsers;
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}
