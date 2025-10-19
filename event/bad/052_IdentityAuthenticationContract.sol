
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct User {
        string name;
        string email;
        bool isVerified;
        bool isActive;
        uint256 registrationTime;
        bytes32 passwordHash;
    }

    mapping(address => User) private users;
    mapping(string => address) private emailToAddress;
    mapping(address => bool) private admins;
    address private owner;
    uint256 private totalUsers;


    event UserRegistered(address userAddress, string email, uint256 timestamp);
    event UserVerified(address userAddress, string email);
    event UserDeactivated(address userAddress, string email);
    event AdminAdded(address adminAddress);
    event AdminRemoved(address adminAddress);


    error InvalidInput();
    error NotAuthorized();
    error UserExists();
    error NotFound();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner);
        _;
    }

    modifier userExists(address _user) {
        require(users[_user].registrationTime > 0);
        _;
    }

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
    }

    function registerUser(
        string memory _name,
        string memory _email,
        string memory _password
    ) external {
        require(bytes(_name).length > 0);
        require(bytes(_email).length > 0);
        require(bytes(_password).length >= 6);
        require(users[msg.sender].registrationTime == 0);
        require(emailToAddress[_email] == address(0));

        bytes32 passwordHash = keccak256(abi.encodePacked(_password, msg.sender));

        users[msg.sender] = User({
            name: _name,
            email: _email,
            isVerified: false,
            isActive: true,
            registrationTime: block.timestamp,
            passwordHash: passwordHash
        });

        emailToAddress[_email] = msg.sender;
        totalUsers++;

        emit UserRegistered(msg.sender, _email, block.timestamp);
    }

    function verifyUser(address _user) external onlyAdmin userExists(_user) {
        require(!users[_user].isVerified);


        users[_user].isVerified = true;
    }

    function deactivateUser(address _user) external onlyAdmin userExists(_user) {
        require(users[_user].isActive);

        users[_user].isActive = false;
        emit UserDeactivated(_user, users[_user].email);
    }

    function reactivateUser(address _user) external onlyAdmin userExists(_user) {
        require(!users[_user].isActive);


        users[_user].isActive = true;
    }

    function authenticateUser(string memory _password) external view userExists(msg.sender) returns (bool) {
        require(users[msg.sender].isActive);

        bytes32 inputHash = keccak256(abi.encodePacked(_password, msg.sender));
        return users[msg.sender].passwordHash == inputHash;
    }

    function updatePassword(string memory _oldPassword, string memory _newPassword) external userExists(msg.sender) {
        require(bytes(_newPassword).length >= 6);
        require(users[msg.sender].isActive);

        bytes32 oldHash = keccak256(abi.encodePacked(_oldPassword, msg.sender));
        require(users[msg.sender].passwordHash == oldHash);

        bytes32 newHash = keccak256(abi.encodePacked(_newPassword, msg.sender));


        users[msg.sender].passwordHash = newHash;
    }

    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0));
        require(!admins[_admin]);

        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != owner);
        require(admins[_admin]);


        admins[_admin] = false;
    }

    function updateUserName(string memory _newName) external userExists(msg.sender) {
        require(bytes(_newName).length > 0);
        require(users[msg.sender].isActive);


        require(users[msg.sender].isVerified);


        users[msg.sender].name = _newName;
    }

    function getUserInfo(address _user) external view userExists(_user) returns (
        string memory name,
        string memory email,
        bool isVerified,
        bool isActive,
        uint256 registrationTime
    ) {
        User memory user = users[_user];
        return (user.name, user.email, user.isVerified, user.isActive, user.registrationTime);
    }

    function isUserVerified(address _user) external view userExists(_user) returns (bool) {
        return users[_user].isVerified;
    }

    function isUserActive(address _user) external view userExists(_user) returns (bool) {
        return users[_user].isActive;
    }

    function isAdmin(address _user) external view returns (bool) {
        return admins[_user];
    }

    function getTotalUsers() external view returns (uint256) {
        return totalUsers;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        require(_newOwner != owner);


        admins[owner] = false;
        owner = _newOwner;
        admins[_newOwner] = true;
    }
}
