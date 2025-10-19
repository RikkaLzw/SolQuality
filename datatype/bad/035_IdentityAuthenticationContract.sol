
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {

    mapping(address => uint256) public userStatus;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public loginAttempts;


    mapping(address => string) public userIds;
    mapping(string => address) public idToAddress;


    mapping(address => bytes) public userHashes;
    mapping(address => bytes) public publicKeys;

    address public owner;


    uint256 public contractActive;
    mapping(address => uint256) public userActive;

    event UserRegistered(address indexed user, string userId);
    event UserVerified(address indexed user);
    event LoginAttempt(address indexed user, uint256 success);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveContract() {
        require(contractActive == 1, "Contract is not active");
        _;
    }

    modifier onlyRegisteredUser() {
        require(userStatus[msg.sender] >= 1, "User not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = 1;
    }

    function registerUser(string memory _userId, bytes memory _userHash)
        external
        onlyActiveContract
    {
        require(userStatus[msg.sender] == 0, "User already registered");
        require(bytes(_userId).length > 0, "User ID cannot be empty");
        require(idToAddress[_userId] == address(0), "User ID already taken");


        userStatus[msg.sender] = uint256(1);
        userLevel[msg.sender] = uint256(0);
        userActive[msg.sender] = uint256(1);
        loginAttempts[msg.sender] = uint256(0);

        userIds[msg.sender] = _userId;
        idToAddress[_userId] = msg.sender;
        userHashes[msg.sender] = _userHash;

        emit UserRegistered(msg.sender, _userId);
    }

    function verifyUser(address _user, bytes memory _publicKey)
        external
        onlyOwner
        onlyActiveContract
    {
        require(userStatus[_user] == 1, "User not registered or already verified");


        userStatus[_user] = uint256(2);
        userLevel[_user] = uint256(1);

        publicKeys[_user] = _publicKey;

        emit UserVerified(_user);
    }

    function authenticate(bytes memory _signature)
        external
        onlyRegisteredUser
        onlyActiveContract
        returns (uint256)
    {
        require(userActive[msg.sender] == 1, "User account is disabled");
        require(loginAttempts[msg.sender] < 5, "Too many failed attempts");


        bool authSuccess = _signature.length > 0 && userHashes[msg.sender].length > 0;

        if (authSuccess) {

            loginAttempts[msg.sender] = uint256(0);
            emit LoginAttempt(msg.sender, uint256(1));
            return uint256(1);
        } else {

            loginAttempts[msg.sender] = uint256(loginAttempts[msg.sender] + 1);
            emit LoginAttempt(msg.sender, uint256(0));
            return uint256(0);
        }
    }

    function updateUserLevel(address _user, uint256 _newLevel)
        external
        onlyOwner
        onlyActiveContract
    {
        require(userStatus[_user] >= 1, "User not registered");
        require(_newLevel <= 5, "Invalid level");

        userLevel[_user] = _newLevel;
    }

    function toggleUserStatus(address _user)
        external
        onlyOwner
        onlyActiveContract
    {
        require(userStatus[_user] >= 1, "User not registered");


        if (userActive[_user] == 1) {
            userActive[_user] = 0;
        } else {
            userActive[_user] = 1;
        }
    }

    function toggleContract() external onlyOwner {

        if (contractActive == 1) {
            contractActive = 0;
        } else {
            contractActive = 1;
        }
    }

    function resetLoginAttempts(address _user)
        external
        onlyOwner
        onlyActiveContract
    {

        loginAttempts[_user] = uint256(0);
    }

    function getUserInfo(address _user)
        external
        view
        returns (
            uint256 status,
            uint256 level,
            uint256 active,
            uint256 attempts,
            string memory userId
        )
    {
        return (
            userStatus[_user],
            userLevel[_user],
            userActive[_user],
            loginAttempts[_user],
            userIds[_user]
        );
    }

    function isUserVerified(address _user) external view returns (uint256) {

        if (userStatus[_user] == 2) {
            return uint256(1);
        } else {
            return uint256(0);
        }
    }
}
