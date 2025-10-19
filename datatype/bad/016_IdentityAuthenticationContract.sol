
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {

    uint256 public constant MAX_ATTEMPTS = 3;
    uint256 public constant MIN_PASSWORD_LENGTH = 8;


    struct Identity {
        string userId;
        string hashedPassword;
        uint256 loginAttempts;
        uint256 isActive;
        uint256 registrationTime;
        bytes additionalData;
    }

    mapping(address => Identity) public identities;
    mapping(string => address) private userIdToAddress;

    address public owner;
    uint256 public totalUsers;

    event UserRegistered(address indexed userAddress, string userId);
    event LoginAttempt(address indexed userAddress, uint256 success);
    event UserDeactivated(address indexed userAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveUser() {

        require(uint256(identities[msg.sender].isActive) == uint256(1), "User not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalUsers = uint256(0);
    }

    function registerUser(
        string memory _userId,
        string memory _hashedPassword,
        bytes memory _additionalData
    ) external {
        require(bytes(_userId).length > 0, "User ID cannot be empty");
        require(bytes(_hashedPassword).length >= MIN_PASSWORD_LENGTH, "Password too short");
        require(userIdToAddress[_userId] == address(0), "User ID already exists");
        require(identities[msg.sender].registrationTime == uint256(0), "Address already registered");

        identities[msg.sender] = Identity({
            userId: _userId,
            hashedPassword: _hashedPassword,
            loginAttempts: uint256(0),
            isActive: uint256(1),
            registrationTime: block.timestamp,
            additionalData: _additionalData
        });

        userIdToAddress[_userId] = msg.sender;
        totalUsers = totalUsers + uint256(1);

        emit UserRegistered(msg.sender, _userId);
    }

    function authenticate(string memory _hashedPassword) external onlyActiveUser returns (uint256) {
        Identity storage user = identities[msg.sender];

        if (keccak256(bytes(user.hashedPassword)) == keccak256(bytes(_hashedPassword))) {
            user.loginAttempts = uint256(0);
            emit LoginAttempt(msg.sender, uint256(1));
            return uint256(1);
        } else {
            user.loginAttempts = user.loginAttempts + uint256(1);

            if (user.loginAttempts >= MAX_ATTEMPTS) {
                user.isActive = uint256(0);
                emit UserDeactivated(msg.sender);
            }

            emit LoginAttempt(msg.sender, uint256(0));
            return uint256(0);
        }
    }

    function updatePassword(
        string memory _currentHashedPassword,
        string memory _newHashedPassword
    ) external onlyActiveUser {
        require(bytes(_newHashedPassword).length >= MIN_PASSWORD_LENGTH, "New password too short");
        require(
            keccak256(bytes(identities[msg.sender].hashedPassword)) == keccak256(bytes(_currentHashedPassword)),
            "Current password incorrect"
        );

        identities[msg.sender].hashedPassword = _newHashedPassword;
        identities[msg.sender].loginAttempts = uint256(0);
    }

    function updateAdditionalData(bytes memory _newData) external onlyActiveUser {
        identities[msg.sender].additionalData = _newData;
    }

    function getUserInfo(address _userAddress) external view returns (
        string memory userId,
        uint256 loginAttempts,
        uint256 isActive,
        uint256 registrationTime,
        bytes memory additionalData
    ) {
        Identity memory user = identities[_userAddress];
        return (
            user.userId,
            user.loginAttempts,
            user.isActive,
            user.registrationTime,
            user.additionalData
        );
    }

    function isUserActive(address _userAddress) external view returns (uint256) {

        return identities[_userAddress].isActive;
    }

    function reactivateUser(address _userAddress) external onlyOwner {
        require(identities[_userAddress].registrationTime > uint256(0), "User not registered");
        identities[_userAddress].isActive = uint256(1);
        identities[_userAddress].loginAttempts = uint256(0);
    }

    function deactivateUser(address _userAddress) external onlyOwner {
        require(identities[_userAddress].registrationTime > uint256(0), "User not registered");
        identities[_userAddress].isActive = uint256(0);
        emit UserDeactivated(_userAddress);
    }

    function getTotalUsers() external view returns (uint256) {
        return totalUsers;
    }

    function getAddressByUserId(string memory _userId) external view returns (address) {
        return userIdToAddress[_userId];
    }
}
