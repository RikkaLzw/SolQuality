
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {


    mapping(address => bool) internal registeredUsers;
    mapping(address => string) public userNames;
    mapping(address => uint256) internal userRegistrationTime;
    mapping(address => bool) public userActiveStatus;
    mapping(address => uint256) internal userLastLoginTime;
    mapping(string => address) public nameToAddress;
    mapping(address => string) public userEmails;
    mapping(address => bool) internal emailVerified;

    address public owner;
    uint256 public totalUsers;
    bool public contractActive;

    event UserRegistered(address indexed user, string name);
    event UserLoggedIn(address indexed user, uint256 timestamp);
    event UserDeactivated(address indexed user);
    event EmailVerified(address indexed user, string email);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        totalUsers = 0;
    }


    function registerUser(string memory _name, string memory _email) public {

        require(bytes(_name).length > 0 && bytes(_name).length <= 50, "Invalid name length");
        require(bytes(_email).length > 0 && bytes(_email).length <= 100, "Invalid email length");
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == false, "User already registered");
        require(nameToAddress[_name] == address(0), "Name already taken");

        registeredUsers[msg.sender] = true;
        userNames[msg.sender] = _name;
        userRegistrationTime[msg.sender] = block.timestamp;
        userActiveStatus[msg.sender] = true;
        userLastLoginTime[msg.sender] = block.timestamp;
        nameToAddress[_name] = msg.sender;
        userEmails[msg.sender] = _email;
        emailVerified[msg.sender] = false;
        totalUsers = totalUsers + 1;

        emit UserRegistered(msg.sender, _name);
    }

    function loginUser() public {
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == true, "User not registered");
        require(userActiveStatus[msg.sender] == true, "User account deactivated");

        userLastLoginTime[msg.sender] = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    function verifyEmail() public {
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == true, "User not registered");
        require(userActiveStatus[msg.sender] == true, "User account deactivated");
        require(emailVerified[msg.sender] == false, "Email already verified");

        emailVerified[msg.sender] = true;

        emit EmailVerified(msg.sender, userEmails[msg.sender]);
    }

    function deactivateUser(address _user) public {
        require(msg.sender == owner, "Only owner can deactivate users");
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[_user] == true, "User not registered");
        require(userActiveStatus[_user] == true, "User already deactivated");

        userActiveStatus[_user] = false;

        emit UserDeactivated(_user);
    }

    function reactivateUser(address _user) public {
        require(msg.sender == owner, "Only owner can reactivate users");
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[_user] == true, "User not registered");
        require(userActiveStatus[_user] == false, "User already active");

        userActiveStatus[_user] = true;
    }

    function updateUserName(string memory _newName) public {

        require(bytes(_newName).length > 0 && bytes(_newName).length <= 50, "Invalid name length");
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == true, "User not registered");
        require(userActiveStatus[msg.sender] == true, "User account deactivated");
        require(nameToAddress[_newName] == address(0), "Name already taken");

        string memory oldName = userNames[msg.sender];
        delete nameToAddress[oldName];
        userNames[msg.sender] = _newName;
        nameToAddress[_newName] = msg.sender;
    }

    function updateUserEmail(string memory _newEmail) public {

        require(bytes(_newEmail).length > 0 && bytes(_newEmail).length <= 100, "Invalid email length");
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == true, "User not registered");
        require(userActiveStatus[msg.sender] == true, "User account deactivated");

        userEmails[msg.sender] = _newEmail;
        emailVerified[msg.sender] = false;
    }

    function getUserInfo(address _user) public view returns (
        string memory name,
        string memory email,
        uint256 registrationTime,
        uint256 lastLoginTime,
        bool isActive,
        bool isEmailVerified
    ) {

        require(registeredUsers[_user] == true, "User not registered");

        return (
            userNames[_user],
            userEmails[_user],
            userRegistrationTime[_user],
            userLastLoginTime[_user],
            userActiveStatus[_user],
            emailVerified[_user]
        );
    }

    function isUserRegistered(address _user) public view returns (bool) {
        return registeredUsers[_user];
    }

    function isUserActive(address _user) public view returns (bool) {

        require(registeredUsers[_user] == true, "User not registered");

        return userActiveStatus[_user];
    }

    function getUserByName(string memory _name) public view returns (address) {
        require(nameToAddress[_name] != address(0), "Name not found");
        return nameToAddress[_name];
    }

    function setContractStatus(bool _status) public {
        require(msg.sender == owner, "Only owner can change contract status");
        contractActive = _status;
    }

    function transferOwnership(address _newOwner) public {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
    }

    function getTotalUsers() public view returns (uint256) {
        return totalUsers;
    }

    function getContractStatus() public view returns (bool) {
        return contractActive;
    }


    function bulkUserOperation(address[] memory _users, bool _activate) public {
        require(msg.sender == owner, "Only owner can perform bulk operations");
        require(contractActive == true, "Contract is not active");


        require(_users.length <= 100, "Too many users in bulk operation");

        for (uint256 i = 0; i < _users.length; i++) {

            require(registeredUsers[_users[i]] == true, "User not registered");

            if (_activate) {
                if (userActiveStatus[_users[i]] == false) {
                    userActiveStatus[_users[i]] = true;
                }
            } else {
                if (userActiveStatus[_users[i]] == true) {
                    userActiveStatus[_users[i]] = false;
                    emit UserDeactivated(_users[i]);
                }
            }
        }
    }


    function authenticateAndLog(string memory _message) public {
        require(contractActive == true, "Contract is not active");


        require(registeredUsers[msg.sender] == true, "User not registered");
        require(userActiveStatus[msg.sender] == true, "User account deactivated");

        userLastLoginTime[msg.sender] = block.timestamp;


        require(bytes(_message).length <= 200, "Message too long");

        emit UserLoggedIn(msg.sender, block.timestamp);
    }
}
