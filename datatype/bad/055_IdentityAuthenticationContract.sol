
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {

    uint256 public constant MAX_ATTEMPTS = 3;
    uint256 public constant LOCKOUT_DURATION = 300;

    struct UserIdentity {

        string userId;
        string email;

        uint256 failedAttempts;
        uint256 lastFailedTime;

        uint256 isActive;
        uint256 isVerified;

        bytes passwordHash;
        bytes publicKey;
    }

    mapping(address => UserIdentity) private users;
    mapping(string => address) private userIdToAddress;

    address public owner;

    uint256 public totalUsers;

    event UserRegistered(address indexed userAddress, string userId);
    event UserAuthenticated(address indexed userAddress, string userId);
    event UserLocked(address indexed userAddress, string userId);
    event UserUnlocked(address indexed userAddress, string userId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier userExists(address userAddress) {

        require(uint256(bytes(users[userAddress].userId).length) > 0, "User does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;

        totalUsers = uint256(0);
    }

    function registerUser(
        string memory _userId,
        string memory _email,
        bytes memory _passwordHash,
        bytes memory _publicKey
    ) external {
        require(bytes(_userId).length > 0, "User ID cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(_passwordHash.length > 0, "Password hash cannot be empty");
        require(userIdToAddress[_userId] == address(0), "User ID already exists");
        require(bytes(users[msg.sender].userId).length == 0, "Address already registered");

        users[msg.sender] = UserIdentity({
            userId: _userId,
            email: _email,

            failedAttempts: uint256(0),
            lastFailedTime: uint256(0),

            isActive: uint256(1),
            isVerified: uint256(0),
            passwordHash: _passwordHash,
            publicKey: _publicKey
        });

        userIdToAddress[_userId] = msg.sender;

        totalUsers = uint256(totalUsers + 1);

        emit UserRegistered(msg.sender, _userId);
    }

    function authenticateUser(bytes memory _passwordHash)
        external
        userExists(msg.sender)
        returns (bool)
    {
        UserIdentity storage user = users[msg.sender];


        if (user.failedAttempts >= MAX_ATTEMPTS) {

            if (uint256(block.timestamp) < user.lastFailedTime + LOCKOUT_DURATION) {
                return false;
            } else {

                user.failedAttempts = uint256(0);
                user.lastFailedTime = uint256(0);
                emit UserUnlocked(msg.sender, user.userId);
            }
        }



        if (user.isActive != uint256(1)) {
            return false;
        }


        if (keccak256(user.passwordHash) == keccak256(_passwordHash)) {

            user.failedAttempts = uint256(0);
            user.lastFailedTime = uint256(0);
            emit UserAuthenticated(msg.sender, user.userId);
            return true;
        } else {


            user.failedAttempts = uint256(user.failedAttempts + 1);
            user.lastFailedTime = uint256(block.timestamp);

            if (user.failedAttempts >= MAX_ATTEMPTS) {
                emit UserLocked(msg.sender, user.userId);
            }
            return false;
        }
    }

    function verifyUser(address userAddress)
        external
        onlyOwner
        userExists(userAddress)
    {

        users[userAddress].isVerified = uint256(1);
    }

    function deactivateUser(address userAddress)
        external
        onlyOwner
        userExists(userAddress)
    {

        users[userAddress].isActive = uint256(0);
    }

    function reactivateUser(address userAddress)
        external
        onlyOwner
        userExists(userAddress)
    {

        users[userAddress].isActive = uint256(1);
    }

    function getUserInfo(address userAddress)
        external
        view
        userExists(userAddress)
        returns (
            string memory userId,
            string memory email,
            uint256 failedAttempts,
            bool isActive,
            bool isVerified
        )
    {
        UserIdentity memory user = users[userAddress];
        return (
            user.userId,
            user.email,
            user.failedAttempts,

            user.isActive == uint256(1),
            user.isVerified == uint256(1)
        );
    }

    function getUserByUserId(string memory _userId)
        external
        view
        returns (address)
    {
        return userIdToAddress[_userId];
    }

    function updateEmail(string memory _newEmail)
        external
        userExists(msg.sender)
    {
        require(bytes(_newEmail).length > 0, "Email cannot be empty");
        users[msg.sender].email = _newEmail;
    }

    function updatePasswordHash(bytes memory _newPasswordHash)
        external
        userExists(msg.sender)
    {
        require(_newPasswordHash.length > 0, "Password hash cannot be empty");
        users[msg.sender].passwordHash = _newPasswordHash;

        users[msg.sender].failedAttempts = uint256(0);
        users[msg.sender].lastFailedTime = uint256(0);
    }

    function isUserLocked(address userAddress)
        external
        view
        userExists(userAddress)
        returns (bool)
    {
        UserIdentity memory user = users[userAddress];
        if (user.failedAttempts >= MAX_ATTEMPTS) {

            return uint256(block.timestamp) < user.lastFailedTime + LOCKOUT_DURATION;
        }
        return false;
    }
}
