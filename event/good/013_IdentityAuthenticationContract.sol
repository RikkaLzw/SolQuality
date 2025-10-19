
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct Identity {
        address owner;
        string name;
        string email;
        bool isVerified;
        uint256 createdAt;
        uint256 lastUpdated;
    }

    mapping(address => Identity) private identities;
    mapping(string => address) private emailToAddress;
    mapping(address => bool) private authorizedVerifiers;

    address public admin;
    uint256 public totalIdentities;

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

    event IdentityUpdated(
        address indexed user,
        string indexed newEmail,
        string newName,
        uint256 timestamp
    );

    event VerifierAuthorized(
        address indexed verifier,
        address indexed admin,
        uint256 timestamp
    );

    event VerifierRevoked(
        address indexed verifier,
        address indexed admin,
        uint256 timestamp
    );

    event AdminTransferred(
        address indexed previousAdmin,
        address indexed newAdmin,
        uint256 timestamp
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "IdentityAuth: caller is not the admin");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(
            authorizedVerifiers[msg.sender] || msg.sender == admin,
            "IdentityAuth: caller is not an authorized verifier"
        );
        _;
    }

    modifier identityExists(address user) {
        require(
            identities[user].owner != address(0),
            "IdentityAuth: identity does not exist"
        );
        _;
    }

    modifier identityNotExists(address user) {
        require(
            identities[user].owner == address(0),
            "IdentityAuth: identity already exists"
        );
        _;
    }

    constructor() {
        admin = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }

    function registerIdentity(
        string memory _name,
        string memory _email
    ) external identityNotExists(msg.sender) {
        require(bytes(_name).length > 0, "IdentityAuth: name cannot be empty");
        require(bytes(_email).length > 0, "IdentityAuth: email cannot be empty");
        require(
            emailToAddress[_email] == address(0),
            "IdentityAuth: email already registered"
        );

        identities[msg.sender] = Identity({
            owner: msg.sender,
            name: _name,
            email: _email,
            isVerified: false,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp
        });

        emailToAddress[_email] = msg.sender;
        totalIdentities++;

        emit IdentityRegistered(msg.sender, _email, _name, block.timestamp);
    }

    function verifyIdentity(
        address _user
    ) external onlyAuthorizedVerifier identityExists(_user) {
        require(
            !identities[_user].isVerified,
            "IdentityAuth: identity already verified"
        );

        identities[_user].isVerified = true;
        identities[_user].lastUpdated = block.timestamp;

        emit IdentityVerified(_user, msg.sender, block.timestamp);
    }

    function updateIdentity(
        string memory _newName,
        string memory _newEmail
    ) external identityExists(msg.sender) {
        require(bytes(_newName).length > 0, "IdentityAuth: name cannot be empty");
        require(bytes(_newEmail).length > 0, "IdentityAuth: email cannot be empty");

        string memory oldEmail = identities[msg.sender].email;

        if (keccak256(bytes(_newEmail)) != keccak256(bytes(oldEmail))) {
            require(
                emailToAddress[_newEmail] == address(0),
                "IdentityAuth: email already registered"
            );

            delete emailToAddress[oldEmail];
            emailToAddress[_newEmail] = msg.sender;

            identities[msg.sender].isVerified = false;
        }

        identities[msg.sender].name = _newName;
        identities[msg.sender].email = _newEmail;
        identities[msg.sender].lastUpdated = block.timestamp;

        emit IdentityUpdated(msg.sender, _newEmail, _newName, block.timestamp);
    }

    function authorizeVerifier(address _verifier) external onlyAdmin {
        require(_verifier != address(0), "IdentityAuth: invalid verifier address");
        require(
            !authorizedVerifiers[_verifier],
            "IdentityAuth: verifier already authorized"
        );

        authorizedVerifiers[_verifier] = true;

        emit VerifierAuthorized(_verifier, msg.sender, block.timestamp);
    }

    function revokeVerifier(address _verifier) external onlyAdmin {
        require(_verifier != admin, "IdentityAuth: cannot revoke admin");
        require(
            authorizedVerifiers[_verifier],
            "IdentityAuth: verifier not authorized"
        );

        authorizedVerifiers[_verifier] = false;

        emit VerifierRevoked(_verifier, msg.sender, block.timestamp);
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "IdentityAuth: invalid admin address");
        require(_newAdmin != admin, "IdentityAuth: new admin is current admin");

        address previousAdmin = admin;
        admin = _newAdmin;
        authorizedVerifiers[_newAdmin] = true;

        emit AdminTransferred(previousAdmin, _newAdmin, block.timestamp);
    }

    function getIdentity(address _user) external view returns (
        address owner,
        string memory name,
        string memory email,
        bool isVerified,
        uint256 createdAt,
        uint256 lastUpdated
    ) {
        require(
            identities[_user].owner != address(0),
            "IdentityAuth: identity does not exist"
        );

        Identity memory identity = identities[_user];
        return (
            identity.owner,
            identity.name,
            identity.email,
            identity.isVerified,
            identity.createdAt,
            identity.lastUpdated
        );
    }

    function isVerifiedIdentity(address _user) external view returns (bool) {
        return identities[_user].owner != address(0) && identities[_user].isVerified;
    }

    function isAuthorizedVerifier(address _verifier) external view returns (bool) {
        return authorizedVerifiers[_verifier];
    }

    function getAddressByEmail(string memory _email) external view returns (address) {
        address userAddress = emailToAddress[_email];
        require(userAddress != address(0), "IdentityAuth: email not registered");
        return userAddress;
    }
}
