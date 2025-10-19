
pragma solidity ^0.8.19;


contract IdentityAuthenticationContract {


    struct UserIdentity {
        string userName;
        string emailAddress;
        bool isVerified;
        bool isActive;
        uint256 registrationTime;
        uint256 lastLoginTime;
        address walletAddress;
    }


    enum PermissionLevel {
        GUEST,
        USER,
        MODERATOR,
        ADMIN
    }


    address public contractOwner;
    uint256 public totalRegisteredUsers;
    uint256 public constant MAX_USERNAME_LENGTH = 50;
    uint256 public constant MIN_USERNAME_LENGTH = 3;


    mapping(address => UserIdentity) public userIdentities;
    mapping(string => address) public usernameToAddress;
    mapping(string => address) public emailToAddress;
    mapping(address => PermissionLevel) public userPermissions;
    mapping(address => bool) public blacklistedUsers;


    event UserRegistered(
        address indexed userAddress,
        string userName,
        string emailAddress,
        uint256 timestamp
    );

    event UserVerified(
        address indexed userAddress,
        uint256 timestamp
    );

    event UserLoggedIn(
        address indexed userAddress,
        uint256 timestamp
    );

    event PermissionChanged(
        address indexed userAddress,
        PermissionLevel oldPermission,
        PermissionLevel newPermission,
        uint256 timestamp
    );

    event UserDeactivated(
        address indexed userAddress,
        uint256 timestamp
    );

    event UserBlacklisted(
        address indexed userAddress,
        bool isBlacklisted,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == contractOwner || userPermissions[msg.sender] == PermissionLevel.ADMIN,
            "Only admin can perform this action"
        );
        _;
    }

    modifier onlyVerifiedUser() {
        require(userIdentities[msg.sender].isVerified, "User must be verified");
        require(userIdentities[msg.sender].isActive, "User account must be active");
        require(!blacklistedUsers[msg.sender], "User is blacklisted");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address provided");
        _;
    }

    modifier validString(string memory _str, uint256 _minLength, uint256 _maxLength) {
        bytes memory strBytes = bytes(_str);
        require(strBytes.length >= _minLength, "String too short");
        require(strBytes.length <= _maxLength, "String too long");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        userPermissions[msg.sender] = PermissionLevel.ADMIN;
        totalRegisteredUsers = 0;
    }


    function registerUser(
        string memory _userName,
        string memory _emailAddress
    )
        external
        validString(_userName, MIN_USERNAME_LENGTH, MAX_USERNAME_LENGTH)
        validString(_emailAddress, 5, 100)
    {
        require(!userIdentities[msg.sender].isActive, "User already registered");
        require(usernameToAddress[_userName] == address(0), "Username already taken");
        require(emailToAddress[_emailAddress] == address(0), "Email already registered");
        require(!blacklistedUsers[msg.sender], "Address is blacklisted");


        userIdentities[msg.sender] = UserIdentity({
            userName: _userName,
            emailAddress: _emailAddress,
            isVerified: false,
            isActive: true,
            registrationTime: block.timestamp,
            lastLoginTime: 0,
            walletAddress: msg.sender
        });


        usernameToAddress[_userName] = msg.sender;
        emailToAddress[_emailAddress] = msg.sender;
        userPermissions[msg.sender] = PermissionLevel.USER;


        totalRegisteredUsers++;


        emit UserRegistered(msg.sender, _userName, _emailAddress, block.timestamp);
    }


    function verifyUser(address _userAddress)
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        require(userIdentities[_userAddress].isActive, "User not registered or inactive");
        require(!userIdentities[_userAddress].isVerified, "User already verified");

        userIdentities[_userAddress].isVerified = true;

        emit UserVerified(_userAddress, block.timestamp);
    }


    function loginUser() external onlyVerifiedUser {
        userIdentities[msg.sender].lastLoginTime = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }


    function changeUserPermission(
        address _userAddress,
        PermissionLevel _newPermission
    )
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        require(userIdentities[_userAddress].isActive, "User not registered or inactive");
        require(_userAddress != contractOwner, "Cannot change owner permissions");

        PermissionLevel oldPermission = userPermissions[_userAddress];
        userPermissions[_userAddress] = _newPermission;

        emit PermissionChanged(_userAddress, oldPermission, _newPermission, block.timestamp);
    }


    function deactivateUser(address _userAddress)
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        require(userIdentities[_userAddress].isActive, "User already inactive");
        require(_userAddress != contractOwner, "Cannot deactivate contract owner");

        userIdentities[_userAddress].isActive = false;

        emit UserDeactivated(_userAddress, block.timestamp);
    }


    function setUserBlacklist(
        address _userAddress,
        bool _isBlacklisted
    )
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        require(_userAddress != contractOwner, "Cannot blacklist contract owner");

        blacklistedUsers[_userAddress] = _isBlacklisted;

        emit UserBlacklisted(_userAddress, _isBlacklisted, block.timestamp);
    }


    function getUserInfo(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (UserIdentity memory)
    {
        return userIdentities[_userAddress];
    }


    function isValidUser(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (bool)
    {
        UserIdentity memory user = userIdentities[_userAddress];
        return user.isVerified && user.isActive && !blacklistedUsers[_userAddress];
    }


    function getUserPermission(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (PermissionLevel)
    {
        return userPermissions[_userAddress];
    }


    function getAddressByUsername(string memory _userName)
        external
        view
        returns (address)
    {
        return usernameToAddress[_userName];
    }


    function getAddressByEmail(string memory _emailAddress)
        external
        view
        returns (address)
    {
        return emailToAddress[_emailAddress];
    }


    function transferOwnership(address _newOwner)
        external
        onlyOwner
        validAddress(_newOwner)
    {
        require(_newOwner != contractOwner, "New owner must be different from current owner");


        userPermissions[contractOwner] = PermissionLevel.USER;
        userPermissions[_newOwner] = PermissionLevel.ADMIN;

        contractOwner = _newOwner;
    }


    function getContractStats()
        external
        view
        returns (uint256 totalUsers, address contractOwnerAddress)
    {
        return (totalRegisteredUsers, contractOwner);
    }
}
