
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


    mapping(string => bool) private emailExists;


    mapping(address => bool) public isAdmin;


    address public owner;


    uint256 public totalUsers;


    event UserRegistered(
        address indexed userAddress,
        string indexed email,
        string name,
        uint256 timestamp
    );

    event UserVerified(
        address indexed userAddress,
        address indexed verifier,
        uint256 timestamp
    );

    event UserDeactivated(
        address indexed userAddress,
        address indexed admin,
        uint256 timestamp
    );

    event UserReactivated(
        address indexed userAddress,
        address indexed admin,
        uint256 timestamp
    );

    event UserLoggedIn(
        address indexed userAddress,
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
        address indexed userAddress,
        bytes32 indexed oldHash,
        bytes32 indexed newHash,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "IdentityAuth: Only contract owner can perform this action");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner, "IdentityAuth: Only admin can perform this action");
        _;
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "IdentityAuth: User must be registered to perform this action");
        _;
    }

    modifier onlyActive() {
        require(identities[msg.sender].isActive, "IdentityAuth: User account is deactivated");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "IdentityAuth: Invalid address - cannot be zero address");
        _;
    }

    modifier notEmpty(string memory _str) {
        require(bytes(_str).length > 0, "IdentityAuth: String parameter cannot be empty");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        emit AdminAdded(msg.sender, msg.sender, block.timestamp);
    }


    function registerUser(
        string memory _name,
        string memory _email,
        bytes32 _documentHash
    ) external notEmpty(_name) notEmpty(_email) {
        if (isRegistered[msg.sender]) {
            revert("IdentityAuth: Address is already registered");
        }

        if (emailExists[_email]) {
            revert("IdentityAuth: Email address is already in use");
        }

        if (_documentHash == bytes32(0)) {
            revert("IdentityAuth: Document hash cannot be empty");
        }

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
        emailExists[_email] = true;
        totalUsers++;

        emit UserRegistered(msg.sender, _email, _name, block.timestamp);
    }


    function verifyUser(address _userAddress)
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        if (!isRegistered[_userAddress]) {
            revert("IdentityAuth: User is not registered");
        }

        if (identities[_userAddress].isVerified) {
            revert("IdentityAuth: User is already verified");
        }

        identities[_userAddress].isVerified = true;

        emit UserVerified(_userAddress, msg.sender, block.timestamp);
    }


    function deactivateUser(address _userAddress)
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        if (!isRegistered[_userAddress]) {
            revert("IdentityAuth: User is not registered");
        }

        if (!identities[_userAddress].isActive) {
            revert("IdentityAuth: User is already deactivated");
        }

        identities[_userAddress].isActive = false;

        emit UserDeactivated(_userAddress, msg.sender, block.timestamp);
    }


    function reactivateUser(address _userAddress)
        external
        onlyAdmin
        validAddress(_userAddress)
    {
        if (!isRegistered[_userAddress]) {
            revert("IdentityAuth: User is not registered");
        }

        if (identities[_userAddress].isActive) {
            revert("IdentityAuth: User is already active");
        }

        identities[_userAddress].isActive = true;

        emit UserReactivated(_userAddress, msg.sender, block.timestamp);
    }


    function login() external onlyRegistered onlyActive {
        identities[msg.sender].lastLoginTime = block.timestamp;

        emit UserLoggedIn(msg.sender, block.timestamp);
    }


    function updateDocumentHash(bytes32 _newDocumentHash)
        external
        onlyRegistered
        onlyActive
    {
        if (_newDocumentHash == bytes32(0)) {
            revert("IdentityAuth: New document hash cannot be empty");
        }

        bytes32 oldHash = identities[msg.sender].documentHash;

        if (oldHash == _newDocumentHash) {
            revert("IdentityAuth: New document hash must be different from current hash");
        }

        identities[msg.sender].documentHash = _newDocumentHash;

        emit DocumentHashUpdated(msg.sender, oldHash, _newDocumentHash, block.timestamp);
    }


    function addAdmin(address _newAdmin)
        external
        onlyOwner
        validAddress(_newAdmin)
    {
        if (isAdmin[_newAdmin]) {
            revert("IdentityAuth: Address is already an admin");
        }

        isAdmin[_newAdmin] = true;

        emit AdminAdded(_newAdmin, msg.sender, block.timestamp);
    }


    function removeAdmin(address _admin)
        external
        onlyOwner
        validAddress(_admin)
    {
        if (_admin == owner) {
            revert("IdentityAuth: Cannot remove contract owner from admin role");
        }

        if (!isAdmin[_admin]) {
            revert("IdentityAuth: Address is not an admin");
        }

        isAdmin[_admin] = false;

        emit AdminRemoved(_admin, msg.sender, block.timestamp);
    }


    function getUserIdentity(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (
            string memory name,
            string memory email,
            bool isVerified,
            bool isActive,
            uint256 registrationTime,
            uint256 lastLoginTime
        )
    {
        require(
            msg.sender == _userAddress || isAdmin[msg.sender] || msg.sender == owner,
            "IdentityAuth: Unauthorized to view this user's information"
        );

        if (!isRegistered[_userAddress]) {
            revert("IdentityAuth: User is not registered");
        }

        Identity memory identity = identities[_userAddress];

        return (
            identity.name,
            identity.email,
            identity.isVerified,
            identity.isActive,
            identity.registrationTime,
            identity.lastLoginTime
        );
    }


    function isAuthenticated(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (bool)
    {
        return isRegistered[_userAddress] &&
               identities[_userAddress].isVerified &&
               identities[_userAddress].isActive;
    }


    function getDocumentHash(address _userAddress)
        external
        view
        onlyAdmin
        validAddress(_userAddress)
        returns (bytes32)
    {
        if (!isRegistered[_userAddress]) {
            revert("IdentityAuth: User is not registered");
        }

        return identities[_userAddress].documentHash;
    }
}
