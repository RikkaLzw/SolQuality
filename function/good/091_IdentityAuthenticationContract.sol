
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

    event IdentityRegistered(address indexed user, string name, string email);
    event IdentityVerified(address indexed user, address indexed verifier);
    event IdentityUpdated(address indexed user, string newName, string newEmail);
    event VerifierAuthorized(address indexed verifier, address indexed admin);
    event VerifierRevoked(address indexed verifier, address indexed admin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender], "Only authorized verifiers can verify identities");
        _;
    }

    modifier onlyIdentityOwner(address user) {
        require(msg.sender == user, "Only identity owner can perform this action");
        _;
    }

    modifier identityExists(address user) {
        require(identities[user].owner != address(0), "Identity does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }

    function registerIdentity(string memory name, string memory email) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(email).length > 0, "Email cannot be empty");
        require(identities[msg.sender].owner == address(0), "Identity already exists");
        require(emailToAddress[email] == address(0), "Email already registered");

        identities[msg.sender] = Identity({
            owner: msg.sender,
            name: name,
            email: email,
            isVerified: false,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp
        });

        emailToAddress[email] = msg.sender;
        totalIdentities++;

        emit IdentityRegistered(msg.sender, name, email);
    }

    function verifyIdentity(address user) external onlyAuthorizedVerifier identityExists(user) {
        require(!identities[user].isVerified, "Identity already verified");

        identities[user].isVerified = true;
        identities[user].lastUpdated = block.timestamp;

        emit IdentityVerified(user, msg.sender);
    }

    function updateIdentity(string memory newName, string memory newEmail) external {
        require(bytes(newName).length > 0, "Name cannot be empty");
        require(bytes(newEmail).length > 0, "Email cannot be empty");
        require(identities[msg.sender].owner != address(0), "Identity does not exist");

        string memory oldEmail = identities[msg.sender].email;

        if (keccak256(bytes(newEmail)) != keccak256(bytes(oldEmail))) {
            require(emailToAddress[newEmail] == address(0), "Email already registered");
            delete emailToAddress[oldEmail];
            emailToAddress[newEmail] = msg.sender;
        }

        identities[msg.sender].name = newName;
        identities[msg.sender].email = newEmail;
        identities[msg.sender].lastUpdated = block.timestamp;

        emit IdentityUpdated(msg.sender, newName, newEmail);
    }

    function authorizeVerifier(address verifier) external onlyAdmin {
        require(verifier != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[verifier], "Verifier already authorized");

        authorizedVerifiers[verifier] = true;

        emit VerifierAuthorized(verifier, msg.sender);
    }

    function revokeVerifier(address verifier) external onlyAdmin {
        require(verifier != admin, "Cannot revoke admin privileges");
        require(authorizedVerifiers[verifier], "Verifier not authorized");

        authorizedVerifiers[verifier] = false;

        emit VerifierRevoked(verifier, msg.sender);
    }

    function getIdentity(address user) external view returns (Identity memory) {
        require(identities[user].owner != address(0), "Identity does not exist");
        return identities[user];
    }

    function isVerified(address user) external view returns (bool) {
        return identities[user].isVerified;
    }

    function isAuthorizedVerifier(address verifier) external view returns (bool) {
        return authorizedVerifiers[verifier];
    }

    function getAddressByEmail(string memory email) external view returns (address) {
        return emailToAddress[email];
    }
}
