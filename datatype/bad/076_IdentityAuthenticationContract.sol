
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {

    uint256 public constant MAX_ATTEMPTS = 3;
    uint256 public constant SESSION_DURATION = 3600;


    struct Identity {
        string userId;
        string username;
        bytes passwordHash;
        uint256 loginAttempts;
        uint256 lastLoginTime;
        uint256 isActive;
        uint256 isVerified;
    }

    mapping(address => Identity) public identities;
    mapping(string => address) public usernameToAddress;


    mapping(string => uint256) public sessionExpiry;

    address public owner;
    uint256 public totalUsers;

    event UserRegistered(address indexed user, string username);
    event UserLoggedIn(address indexed user, string sessionId);
    event UserLoggedOut(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveUser() {
        require(identities[msg.sender].isActive == uint256(1), "User not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalUsers = uint256(0);
    }

    function registerUser(
        string memory _userId,
        string memory _username,
        bytes memory _passwordHash
    ) public {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(_passwordHash.length > 0, "Password hash cannot be empty");
        require(usernameToAddress[_username] == address(0), "Username already exists");
        require(identities[msg.sender].isActive == uint256(0), "User already registered");

        identities[msg.sender] = Identity({
            userId: _userId,
            username: _username,
            passwordHash: _passwordHash,
            loginAttempts: uint256(0),
            lastLoginTime: uint256(0),
            isActive: uint256(1),
            isVerified: uint256(0)
        });

        usernameToAddress[_username] = msg.sender;
        totalUsers = totalUsers + uint256(1);

        emit UserRegistered(msg.sender, _username);
    }

    function login(
        string memory _username,
        bytes memory _passwordHash,
        string memory _sessionId
    ) public returns (uint256) {
        address userAddress = usernameToAddress[_username];
        require(userAddress != address(0), "User not found");
        require(identities[userAddress].isActive == uint256(1), "User not active");

        Identity storage user = identities[userAddress];

        if (user.loginAttempts >= MAX_ATTEMPTS) {
            return uint256(0);
        }

        if (keccak256(user.passwordHash) != keccak256(_passwordHash)) {
            user.loginAttempts = user.loginAttempts + uint256(1);
            return uint256(0);
        }


        user.loginAttempts = uint256(0);
        user.lastLoginTime = block.timestamp;
        sessionExpiry[_sessionId] = block.timestamp + SESSION_DURATION;

        emit UserLoggedIn(userAddress, _sessionId);
        return uint256(1);
    }

    function logout(string memory _sessionId) public onlyActiveUser {
        sessionExpiry[_sessionId] = uint256(0);
        emit UserLoggedOut(msg.sender);
    }

    function verifyUser(address _user) public onlyOwner {
        require(identities[_user].isActive == uint256(1), "User not active");
        identities[_user].isVerified = uint256(1);
    }

    function deactivateUser(address _user) public onlyOwner {
        identities[_user].isActive = uint256(0);
    }

    function isSessionValid(string memory _sessionId) public view returns (uint256) {
        if (sessionExpiry[_sessionId] > block.timestamp) {
            return uint256(1);
        }
        return uint256(0);
    }

    function getUserInfo(address _user) public view returns (
        string memory userId,
        string memory username,
        uint256 loginAttempts,
        uint256 lastLoginTime,
        uint256 isActive,
        uint256 isVerified
    ) {
        Identity memory user = identities[_user];
        return (
            user.userId,
            user.username,
            user.loginAttempts,
            user.lastLoginTime,
            user.isActive,
            user.isVerified
        );
    }

    function resetLoginAttempts(address _user) public onlyOwner {
        identities[_user].loginAttempts = uint256(0);
    }

    function updatePassword(bytes memory _newPasswordHash) public onlyActiveUser {
        require(_newPasswordHash.length > 0, "Password hash cannot be empty");
        identities[msg.sender].passwordHash = _newPasswordHash;
    }
}
