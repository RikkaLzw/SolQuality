
pragma solidity ^0.8.0;


contract IdentityAuthenticationContract {


    struct UserIdentity {
        string userName;
        string emailAddress;
        bytes32 passwordHash;
        bool isVerified;
        bool isActive;
        uint256 registrationTime;
        uint256 lastLoginTime;
        address walletAddress;
    }


    enum UserRole {
        GUEST,
        USER,
        MODERATOR,
        ADMIN
    }


    address public contractOwner;
    uint256 public totalRegisteredUsers;
    uint256 public constant MAX_LOGIN_ATTEMPTS = 5;
    uint256 public constant LOCKOUT_DURATION = 1 hours;


    mapping(address => UserIdentity) public userIdentities;
    mapping(address => UserRole) public userRoles;
    mapping(address => uint256) public loginAttempts;
    mapping(address => uint256) public lockoutEndTime;
    mapping(string => address) public usernameToAddress;
    mapping(string => address) public emailToAddress;


    event UserRegistered(
        address indexed userAddress,
        string userName,
        string emailAddress,
        uint256 timestamp
    );

    event UserLoggedIn(
        address indexed userAddress,
        uint256 timestamp
    );

    event UserVerified(
        address indexed userAddress,
        uint256 timestamp
    );

    event UserRoleChanged(
        address indexed userAddress,
        UserRole oldRole,
        UserRole newRole,
        uint256 timestamp
    );

    event AccountLocked(
        address indexed userAddress,
        uint256 lockoutEndTime
    );

    event AccountUnlocked(
        address indexed userAddress,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAdmin() {
        require(
            userRoles[msg.sender] == UserRole.ADMIN || msg.sender == contractOwner,
            "Only admin can perform this action"
        );
        _;
    }

    modifier onlyVerifiedUser() {
        require(userIdentities[msg.sender].isVerified, "User must be verified");
        require(userIdentities[msg.sender].isActive, "User account must be active");
        _;
    }

    modifier notLocked() {
        require(
            lockoutEndTime[msg.sender] == 0 || block.timestamp > lockoutEndTime[msg.sender],
            "Account is currently locked"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        userRoles[msg.sender] = UserRole.ADMIN;
        totalRegisteredUsers = 0;
    }


    function registerUser(
        string memory _userName,
        string memory _emailAddress,
        bytes32 _passwordHash
    ) external {
        require(bytes(_userName).length > 0, "Username cannot be empty");
        require(bytes(_emailAddress).length > 0, "Email address cannot be empty");
        require(_passwordHash != bytes32(0), "Password hash cannot be empty");
        require(userIdentities[msg.sender].walletAddress == address(0), "User already registered");
        require(usernameToAddress[_userName] == address(0), "Username already exists");
        require(emailToAddress[_emailAddress] == address(0), "Email already registered");


        userIdentities[msg.sender] = UserIdentity({
            userName: _userName,
            emailAddress: _emailAddress,
            passwordHash: _passwordHash,
            isVerified: false,
            isActive: true,
            registrationTime: block.timestamp,
            lastLoginTime: 0,
            walletAddress: msg.sender
        });


        userRoles[msg.sender] = UserRole.USER;


        usernameToAddress[_userName] = msg.sender;
        emailToAddress[_emailAddress] = msg.sender;


        totalRegisteredUsers++;


        emit UserRegistered(msg.sender, _userName, _emailAddress, block.timestamp);
    }


    function loginUser(bytes32 _passwordHash) external notLocked {
        require(userIdentities[msg.sender].walletAddress != address(0), "User not registered");
        require(userIdentities[msg.sender].isActive, "Account is not active");


        if (userIdentities[msg.sender].passwordHash != _passwordHash) {
            loginAttempts[msg.sender]++;


            if (loginAttempts[msg.sender] >= MAX_LOGIN_ATTEMPTS) {
                lockoutEndTime[msg.sender] = block.timestamp + LOCKOUT_DURATION;
                emit AccountLocked(msg.sender, lockoutEndTime[msg.sender]);
            }

            revert("Invalid password");
        }


        loginAttempts[msg.sender] = 0;
        userIdentities[msg.sender].lastLoginTime = block.timestamp;


        emit UserLoggedIn(msg.sender, block.timestamp);
    }


    function verifyUser(address _userAddress) external onlyAdmin {
        require(userIdentities[_userAddress].walletAddress != address(0), "User not registered");
        require(!userIdentities[_userAddress].isVerified, "User already verified");

        userIdentities[_userAddress].isVerified = true;

        emit UserVerified(_userAddress, block.timestamp);
    }


    function changeUserRole(address _userAddress, UserRole _newRole) external onlyAdmin {
        require(userIdentities[_userAddress].walletAddress != address(0), "User not registered");
        require(_userAddress != contractOwner, "Cannot change owner role");

        UserRole oldRole = userRoles[_userAddress];
        userRoles[_userAddress] = _newRole;

        emit UserRoleChanged(_userAddress, oldRole, _newRole, block.timestamp);
    }


    function setUserActiveStatus(address _userAddress, bool _isActive) external onlyAdmin {
        require(userIdentities[_userAddress].walletAddress != address(0), "User not registered");
        require(_userAddress != contractOwner, "Cannot deactivate owner account");

        userIdentities[_userAddress].isActive = _isActive;
    }


    function unlockUserAccount(address _userAddress) external onlyAdmin {
        require(lockoutEndTime[_userAddress] > 0, "Account is not locked");

        lockoutEndTime[_userAddress] = 0;
        loginAttempts[_userAddress] = 0;

        emit AccountUnlocked(_userAddress, block.timestamp);
    }


    function updatePassword(bytes32 _newPasswordHash) external onlyVerifiedUser {
        require(_newPasswordHash != bytes32(0), "Password hash cannot be empty");
        require(
            _newPasswordHash != userIdentities[msg.sender].passwordHash,
            "New password must be different from current password"
        );

        userIdentities[msg.sender].passwordHash = _newPasswordHash;
    }


    function getUserInfo(address _userAddress) external view returns (
        string memory userName,
        string memory emailAddress,
        bool isVerified,
        bool isActive,
        uint256 registrationTime,
        uint256 lastLoginTime
    ) {
        require(
            msg.sender == _userAddress ||
            userRoles[msg.sender] == UserRole.ADMIN ||
            msg.sender == contractOwner,
            "Unauthorized access to user information"
        );

        UserIdentity memory user = userIdentities[_userAddress];
        return (
            user.userName,
            user.emailAddress,
            user.isVerified,
            user.isActive,
            user.registrationTime,
            user.lastLoginTime
        );
    }


    function isUserRegistered(address _userAddress) external view returns (bool) {
        return userIdentities[_userAddress].walletAddress != address(0);
    }


    function isAccountLocked(address _userAddress) external view returns (bool) {
        return lockoutEndTime[_userAddress] > 0 && block.timestamp <= lockoutEndTime[_userAddress];
    }


    function getUserRole(address _userAddress) external view returns (UserRole) {
        return userRoles[_userAddress];
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != contractOwner, "New owner must be different from current owner");


        userRoles[contractOwner] = UserRole.USER;


        contractOwner = _newOwner;
        userRoles[_newOwner] = UserRole.ADMIN;
    }
}
