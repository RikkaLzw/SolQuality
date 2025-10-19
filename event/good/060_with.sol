
pragma solidity ^0.8.0;


contract IdentityAuthenticationContract {

    struct Identity {
        string name;
        string email;
        bool isVerified;
        bool isActive;
        uint256 registrationTime;
        uint256 lastLoginTime;
        bytes32 documentHash;
    }


    mapping(address => Identity) private identities;


    mapping(address => bool) public isRegistered;


    mapping(string => address) private emailToAddress;


    mapping(address => bool) public isAdmin;


    address public owner;


    bool public contractActive = true;


    event IdentityRegistered(
        address indexed user,
        string indexed email,
        string name,
        uint256 timestamp
    );

    event IdentityVerified(
        address indexed user,
        address indexed verifier,
        uint256 timestamp
    );

    event IdentityDeactivated(
        address indexed user,
        address indexed admin,
        uint256 timestamp
    );

    event IdentityReactivated(
        address indexed user,
        address indexed admin,
        uint256 timestamp
    );

    event UserLogin(
        address indexed user,
        uint256 timestamp
    );

    event AdminAdded(
        address indexed newAdmin,
        address indexed addedBy,
        uint256 timestamp
    );

    event AdminRemoved(
        address indexed removedAdmin,
        address indexed removedBy,
        uint256 timestamp
    );

    event DocumentHashUpdated(
        address indexed user,
        bytes32 indexed newHash,
        uint256 timestamp
    );


    error ContractNotActive();
    error OnlyOwner();
    error OnlyAdmin();
    error OnlyRegisteredUser();
    error UserAlreadyRegistered();
    error UserNotRegistered();
    error EmailAlreadyExists();
    error InvalidEmailFormat();
    error InvalidName();
    error UserNotVerified();
    error UserNotActive();
    error CannotRemoveOwnerAdmin();
    error AdminAlreadyExists();
    error AdminDoesNotExist();


    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyAdmin() {
        if (!isAdmin[msg.sender] && msg.sender != owner) revert OnlyAdmin();
        _;
    }

    modifier onlyRegistered() {
        if (!isRegistered[msg.sender]) revert OnlyRegisteredUser();
        _;
    }

    modifier contractIsActive() {
        if (!contractActive) revert ContractNotActive();
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }


    function registerIdentity(
        string memory _name,
        string memory _email,
        bytes32 _documentHash
    ) external contractIsActive {
        if (isRegistered[msg.sender]) revert UserAlreadyRegistered();
        if (bytes(_name).length == 0) revert InvalidName();
        if (bytes(_email).length == 0) revert InvalidEmailFormat();
        if (emailToAddress[_email] != address(0)) revert EmailAlreadyExists();

        identities[msg.sender] = Identity({
            name: _name,
            email: _email,
            isVerified: false,
            isActive: true,
            registrationTime: block.timestamp,
            lastLoginTime: 0,
            documentHash: _documentHash
        });

        isRegistered[msg.sender] = true;
        emailToAddress[_email] = msg.sender;

        emit IdentityRegistered(msg.sender, _email, _name, block.timestamp);
    }


    function verifyIdentity(address _user) external onlyAdmin contractIsActive {
        if (!isRegistered[_user]) revert UserNotRegistered();

        identities[_user].isVerified = true;

        emit IdentityVerified(_user, msg.sender, block.timestamp);
    }


    function deactivateIdentity(address _user) external onlyAdmin contractIsActive {
        if (!isRegistered[_user]) revert UserNotRegistered();

        identities[_user].isActive = false;

        emit IdentityDeactivated(_user, msg.sender, block.timestamp);
    }


    function reactivateIdentity(address _user) external onlyAdmin contractIsActive {
        if (!isRegistered[_user]) revert UserNotRegistered();

        identities[_user].isActive = true;

        emit IdentityReactivated(_user, msg.sender, block.timestamp);
    }


    function login() external onlyRegistered contractIsActive {
        if (!identities[msg.sender].isVerified) revert UserNotVerified();
        if (!identities[msg.sender].isActive) revert UserNotActive();

        identities[msg.sender].lastLoginTime = block.timestamp;

        emit UserLogin(msg.sender, block.timestamp);
    }


    function updateDocumentHash(bytes32 _newDocumentHash) external onlyRegistered contractIsActive {
        if (!identities[msg.sender].isActive) revert UserNotActive();

        identities[msg.sender].documentHash = _newDocumentHash;
        identities[msg.sender].isVerified = false;

        emit DocumentHashUpdated(msg.sender, _newDocumentHash, block.timestamp);
    }


    function addAdmin(address _newAdmin) external onlyOwner {
        if (isAdmin[_newAdmin]) revert AdminAlreadyExists();

        isAdmin[_newAdmin] = true;

        emit AdminAdded(_newAdmin, msg.sender, block.timestamp);
    }


    function removeAdmin(address _admin) external onlyOwner {
        if (_admin == owner) revert CannotRemoveOwnerAdmin();
        if (!isAdmin[_admin]) revert AdminDoesNotExist();

        isAdmin[_admin] = false;

        emit AdminRemoved(_admin, msg.sender, block.timestamp);
    }


    function getIdentity(address _user) external view returns (Identity memory) {
        if (!isRegistered[_user]) revert UserNotRegistered();
        return identities[_user];
    }


    function isAuthenticated(address _user) external view returns (bool) {
        if (!isRegistered[_user]) return false;
        Identity memory identity = identities[_user];
        return identity.isVerified && identity.isActive;
    }


    function getAddressByEmail(string memory _email) external view returns (address) {
        return emailToAddress[_email];
    }


    function setContractActive(bool _active) external onlyOwner {
        contractActive = _active;
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");


        isAdmin[owner] = false;
        isAdmin[_newOwner] = true;
        owner = _newOwner;
    }
}
