
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct UserIdentity {
        string name;
        string email;
        bool isVerified;
        uint256 registrationTime;
        address verifier;
    }

    mapping(address => UserIdentity) private users;
    mapping(address => bool) private admins;
    address private owner;
    uint256 private totalUsers;


    event UserRegistered(address user, string name, string email);
    event UserVerified(address user, address verifier);
    event AdminAdded(address admin);
    event AdminRemoved(address admin);


    error BadInput();
    error NotAllowed();
    error AlreadyExists();
    error NotFound();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
    }

    function registerUser(string memory _name, string memory _email) external {
        require(bytes(_name).length > 0);
        require(bytes(_email).length > 0);
        require(!isUserRegistered(msg.sender));

        users[msg.sender] = UserIdentity({
            name: _name,
            email: _email,
            isVerified: false,
            registrationTime: block.timestamp,
            verifier: address(0)
        });

        totalUsers++;

        emit UserRegistered(msg.sender, _name, _email);
    }

    function verifyUser(address _user) external onlyAdmin {
        require(isUserRegistered(_user));
        require(!users[_user].isVerified);

        users[_user].isVerified = true;
        users[_user].verifier = msg.sender;



        emit UserVerified(_user, msg.sender);
    }

    function updateUserInfo(string memory _name, string memory _email) external {
        require(isUserRegistered(msg.sender));
        require(bytes(_name).length > 0);
        require(bytes(_email).length > 0);

        users[msg.sender].name = _name;
        users[msg.sender].email = _email;


    }

    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0));
        require(!admins[_admin]);

        admins[_admin] = true;



        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != address(0));
        require(_admin != owner);
        require(admins[_admin]);

        admins[_admin] = false;

        emit AdminRemoved(_admin);
    }

    function revokeVerification(address _user) external onlyAdmin {
        if (!isUserRegistered(_user)) {
            revert NotFound();
        }
        if (!users[_user].isVerified) {
            revert BadInput();
        }

        users[_user].isVerified = false;
        users[_user].verifier = address(0);


    }

    function deleteUser(address _user) external {
        require(msg.sender == _user || admins[msg.sender] || msg.sender == owner);
        require(isUserRegistered(_user));

        delete users[_user];
        totalUsers--;


    }

    function getUserInfo(address _user) external view returns (
        string memory name,
        string memory email,
        bool isVerified,
        uint256 registrationTime,
        address verifier
    ) {
        require(isUserRegistered(_user));

        UserIdentity memory user = users[_user];
        return (user.name, user.email, user.isVerified, user.registrationTime, user.verifier);
    }

    function isUserRegistered(address _user) public view returns (bool) {
        return bytes(users[_user].name).length > 0;
    }

    function isUserVerified(address _user) external view returns (bool) {
        require(isUserRegistered(_user));
        return users[_user].isVerified;
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
