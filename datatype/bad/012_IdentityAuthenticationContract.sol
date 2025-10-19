
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct UserIdentity {
        string userId;
        uint256 userLevel;
        bytes userHash;
        uint256 isActive;
        uint256 registrationTime;
        string userRole;
    }

    mapping(address => UserIdentity) private identities;
    mapping(string => address) private userIdToAddress;

    address public owner;
    uint256 private constant ADMIN_LEVEL = uint256(1);
    uint256 private constant USER_LEVEL = uint256(0);

    event UserRegistered(address indexed user, string userId);
    event UserAuthenticated(address indexed user, string userId);
    event UserDeactivated(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveUser() {
        require(identities[msg.sender].isActive == uint256(1), "User is not active");
        _;
    }

    constructor() {
        owner = msg.sender;

        identities[owner] = UserIdentity({
            userId: "ADMIN_001",
            userLevel: ADMIN_LEVEL,
            userHash: abi.encodePacked("admin"),
            isActive: uint256(1),
            registrationTime: block.timestamp,
            userRole: "ADMINISTRATOR"
        });
        userIdToAddress["ADMIN_001"] = owner;
    }

    function registerUser(
        string memory _userId,
        bytes memory _userHash,
        string memory _userRole
    ) public {
        require(bytes(_userId).length > 0, "User ID cannot be empty");
        require(_userHash.length > 0, "User hash cannot be empty");
        require(userIdToAddress[_userId] == address(0), "User ID already exists");
        require(identities[msg.sender].isActive == uint256(0), "User already registered");

        identities[msg.sender] = UserIdentity({
            userId: _userId,
            userLevel: USER_LEVEL,
            userHash: _userHash,
            isActive: uint256(1),
            registrationTime: block.timestamp,
            userRole: _userRole
        });

        userIdToAddress[_userId] = msg.sender;

        emit UserRegistered(msg.sender, _userId);
    }

    function authenticateUser(string memory _userId, bytes memory _providedHash) public view returns (uint256) {
        address userAddress = userIdToAddress[_userId];
        require(userAddress != address(0), "User does not exist");

        UserIdentity memory user = identities[userAddress];
        require(user.isActive == uint256(1), "User is not active");

        if (keccak256(user.userHash) == keccak256(_providedHash)) {
            return uint256(1);
        } else {
            return uint256(0);
        }
    }

    function getUserInfo(address _userAddress) public view returns (
        string memory userId,
        uint256 userLevel,
        bytes memory userHash,
        uint256 isActive,
        uint256 registrationTime,
        string memory userRole
    ) {
        UserIdentity memory user = identities[_userAddress];
        return (
            user.userId,
            user.userLevel,
            user.userHash,
            user.isActive,
            user.registrationTime,
            user.userRole
        );
    }

    function deactivateUser(string memory _userId) public onlyOwner {
        address userAddress = userIdToAddress[_userId];
        require(userAddress != address(0), "User does not exist");
        require(userAddress != owner, "Cannot deactivate owner");

        identities[userAddress].isActive = uint256(0);

        emit UserDeactivated(userAddress);
    }

    function reactivateUser(string memory _userId) public onlyOwner {
        address userAddress = userIdToAddress[_userId];
        require(userAddress != address(0), "User does not exist");

        identities[userAddress].isActive = uint256(1);
    }

    function promoteUser(string memory _userId) public onlyOwner {
        address userAddress = userIdToAddress[_userId];
        require(userAddress != address(0), "User does not exist");
        require(identities[userAddress].isActive == uint256(1), "User is not active");

        identities[userAddress].userLevel = uint256(1);
    }

    function isUserActive(address _userAddress) public view returns (uint256) {
        return identities[_userAddress].isActive;
    }

    function getUserLevel(address _userAddress) public view returns (uint256) {
        return identities[_userAddress].userLevel;
    }

    function updateUserHash(bytes memory _newHash) public onlyActiveUser {
        require(_newHash.length > 0, "Hash cannot be empty");
        identities[msg.sender].userHash = _newHash;
    }
}
