
pragma solidity ^0.8.0;


library AccessControlLib {

    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }


    function getRoleHash(string memory role, address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(role, user));
    }
}


abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(AccessControlLib.isValidAddress(newOwner), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract IdentityAuthenticationContract is Ownable {
    using AccessControlLib for address;


    uint256 public constant MAX_FAILED_ATTEMPTS = 5;
    uint256 public constant LOCKOUT_DURATION = 1 hours;
    uint256 public constant SESSION_DURATION = 24 hours;


    enum UserStatus { Inactive, Active, Suspended, Locked }
    enum AuthLevel { Basic, Verified, Premium }


    struct UserProfile {
        string username;
        bytes32 passwordHash;
        UserStatus status;
        AuthLevel authLevel;
        uint256 createdAt;
        uint256 lastLogin;
        uint256 failedAttempts;
        uint256 lockoutUntil;
        bool twoFactorEnabled;
        bytes32 twoFactorSecret;
    }

    struct AuthSession {
        address user;
        uint256 expiresAt;
        bool isActive;
        string ipAddress;
    }


    mapping(address => UserProfile) private _users;
    mapping(bytes32 => AuthSession) private _sessions;
    mapping(address => bool) private _administrators;
    mapping(string => address) private _usernameToAddress;

    address[] private _userList;
    uint256 private _totalUsers;
    bool private _registrationOpen;


    event UserRegistered(address indexed user, string username, AuthLevel authLevel);
    event UserAuthenticated(address indexed user, bytes32 sessionId);
    event UserLoggedOut(address indexed user, bytes32 sessionId);
    event UserStatusChanged(address indexed user, UserStatus oldStatus, UserStatus newStatus);
    event AuthLevelChanged(address indexed user, AuthLevel oldLevel, AuthLevel newLevel);
    event TwoFactorEnabled(address indexed user);
    event TwoFactorDisabled(address indexed user);
    event UserLocked(address indexed user, uint256 lockoutUntil);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);


    modifier onlyAdmin() {
        require(_administrators[msg.sender] || msg.sender == owner(), "Access denied: Admin required");
        _;
    }

    modifier onlyActiveUser() {
        require(_users[msg.sender].status == UserStatus.Active, "User account is not active");
        _;
    }

    modifier registrationEnabled() {
        require(_registrationOpen, "Registration is currently closed");
        _;
    }

    modifier validAddress(address addr) {
        require(AccessControlLib.isValidAddress(addr), "Invalid address provided");
        _;
    }

    modifier userExists(address user) {
        require(_users[user].createdAt > 0, "User does not exist");
        _;
    }

    modifier notLocked(address user) {
        require(
            _users[user].lockoutUntil == 0 || block.timestamp > _users[user].lockoutUntil,
            "Account is temporarily locked"
        );
        _;
    }

    constructor() {
        _registrationOpen = true;
        _administrators[msg.sender] = true;
        emit AdminAdded(msg.sender);
    }


    function registerUser(
        string memory username,
        string memory password
    ) external registrationEnabled {
        require(bytes(username).length > 0, "Username cannot be empty");
        require(bytes(password).length >= 8, "Password must be at least 8 characters");
        require(_usernameToAddress[username] == address(0), "Username already exists");
        require(_users[msg.sender].createdAt == 0, "User already registered");

        bytes32 passwordHash = keccak256(abi.encodePacked(password, msg.sender));

        _users[msg.sender] = UserProfile({
            username: username,
            passwordHash: passwordHash,
            status: UserStatus.Active,
            authLevel: AuthLevel.Basic,
            createdAt: block.timestamp,
            lastLogin: 0,
            failedAttempts: 0,
            lockoutUntil: 0,
            twoFactorEnabled: false,
            twoFactorSecret: bytes32(0)
        });

        _usernameToAddress[username] = msg.sender;
        _userList.push(msg.sender);
        _totalUsers++;

        emit UserRegistered(msg.sender, username, AuthLevel.Basic);
    }


    function authenticateUser(
        string memory password,
        string memory ipAddress
    ) external onlyActiveUser notLocked(msg.sender) returns (bytes32 sessionId) {
        UserProfile storage user = _users[msg.sender];
        bytes32 passwordHash = keccak256(abi.encodePacked(password, msg.sender));

        if (user.passwordHash != passwordHash) {
            user.failedAttempts++;

            if (user.failedAttempts >= MAX_FAILED_ATTEMPTS) {
                user.lockoutUntil = block.timestamp + LOCKOUT_DURATION;
                emit UserLocked(msg.sender, user.lockoutUntil);
            }

            revert("Invalid credentials");
        }


        user.failedAttempts = 0;
        user.lastLogin = block.timestamp;


        sessionId = keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty));

        _sessions[sessionId] = AuthSession({
            user: msg.sender,
            expiresAt: block.timestamp + SESSION_DURATION,
            isActive: true,
            ipAddress: ipAddress
        });

        emit UserAuthenticated(msg.sender, sessionId);
        return sessionId;
    }


    function verifySession(bytes32 sessionId) external view returns (bool isValid, address user) {
        AuthSession memory session = _sessions[sessionId];

        if (session.isActive && block.timestamp <= session.expiresAt) {
            return (true, session.user);
        }

        return (false, address(0));
    }


    function logout(bytes32 sessionId) external {
        AuthSession storage session = _sessions[sessionId];
        require(session.user == msg.sender, "Unauthorized session access");
        require(session.isActive, "Session already inactive");

        session.isActive = false;
        emit UserLoggedOut(msg.sender, sessionId);
    }


    function enableTwoFactor(bytes32 secret) external onlyActiveUser {
        require(secret != bytes32(0), "Invalid 2FA secret");

        UserProfile storage user = _users[msg.sender];
        user.twoFactorEnabled = true;
        user.twoFactorSecret = secret;

        emit TwoFactorEnabled(msg.sender);
    }


    function disableTwoFactor() external onlyActiveUser {
        UserProfile storage user = _users[msg.sender];
        require(user.twoFactorEnabled, "2FA is not enabled");

        user.twoFactorEnabled = false;
        user.twoFactorSecret = bytes32(0);

        emit TwoFactorDisabled(msg.sender);
    }


    function changePassword(string memory oldPassword, string memory newPassword) external onlyActiveUser {
        require(bytes(newPassword).length >= 8, "New password must be at least 8 characters");

        UserProfile storage user = _users[msg.sender];
        bytes32 oldPasswordHash = keccak256(abi.encodePacked(oldPassword, msg.sender));
        require(user.passwordHash == oldPasswordHash, "Invalid current password");

        user.passwordHash = keccak256(abi.encodePacked(newPassword, msg.sender));
    }


    function setUserStatus(address user, UserStatus newStatus)
        external
        onlyAdmin
        validAddress(user)
        userExists(user)
    {
        UserStatus oldStatus = _users[user].status;
        _users[user].status = newStatus;


        if (newStatus == UserStatus.Active) {
            _users[user].lockoutUntil = 0;
            _users[user].failedAttempts = 0;
        }

        emit UserStatusChanged(user, oldStatus, newStatus);
    }


    function upgradeAuthLevel(address user, AuthLevel newLevel)
        external
        onlyAdmin
        validAddress(user)
        userExists(user)
    {
        AuthLevel oldLevel = _users[user].authLevel;
        _users[user].authLevel = newLevel;

        emit AuthLevelChanged(user, oldLevel, newLevel);
    }


    function addAdmin(address admin) external onlyOwner validAddress(admin) {
        require(!_administrators[admin], "Address is already an admin");
        _administrators[admin] = true;
        emit AdminAdded(admin);
    }


    function removeAdmin(address admin) external onlyOwner validAddress(admin) {
        require(_administrators[admin], "Address is not an admin");
        require(admin != owner(), "Cannot remove contract owner as admin");
        _administrators[admin] = false;
        emit AdminRemoved(admin);
    }


    function setRegistrationStatus(bool isOpen) external onlyAdmin {
        _registrationOpen = isOpen;
    }



    function getUserProfile(address user) external view returns (
        string memory username,
        UserStatus status,
        AuthLevel authLevel,
        uint256 createdAt,
        uint256 lastLogin,
        bool twoFactorEnabled
    ) {
        UserProfile memory profile = _users[user];
        return (
            profile.username,
            profile.status,
            profile.authLevel,
            profile.createdAt,
            profile.lastLogin,
            profile.twoFactorEnabled
        );
    }

    function isAdmin(address addr) external view returns (bool) {
        return _administrators[addr] || addr == owner();
    }

    function isRegistrationOpen() external view returns (bool) {
        return _registrationOpen;
    }

    function getTotalUsers() external view returns (uint256) {
        return _totalUsers;
    }

    function getUserByUsername(string memory username) external view returns (address) {
        return _usernameToAddress[username];
    }

    function isUserLocked(address user) external view returns (bool, uint256) {
        UserProfile memory profile = _users[user];
        bool locked = profile.lockoutUntil > 0 && block.timestamp <= profile.lockoutUntil;
        return (locked, profile.lockoutUntil);
    }
}
