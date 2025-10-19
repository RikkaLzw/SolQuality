
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct Identity {
        bytes32 identityHash;
        bytes32 publicKeyHash;
        uint64 timestamp;
        bool isVerified;
        bool isActive;
    }

    mapping(address => Identity) private identities;
    mapping(bytes32 => address) private identityHashToAddress;
    mapping(address => bool) private authorizedVerifiers;

    address private owner;
    uint256 private totalIdentities;

    event IdentityRegistered(address indexed user, bytes32 indexed identityHash, uint64 timestamp);
    event IdentityVerified(address indexed user, bytes32 indexed identityHash, address indexed verifier);
    event IdentityRevoked(address indexed user, bytes32 indexed identityHash);
    event VerifierAuthorized(address indexed verifier);
    event VerifierRevoked(address indexed verifier);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender], "Only authorized verifiers can perform this action");
        _;
    }

    modifier identityExists(address user) {
        require(identities[user].timestamp != 0, "Identity does not exist");
        _;
    }

    modifier identityNotExists(address user) {
        require(identities[user].timestamp == 0, "Identity already exists");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }

    function registerIdentity(bytes32 _identityHash, bytes32 _publicKeyHash)
        external
        identityNotExists(msg.sender)
    {
        require(_identityHash != bytes32(0), "Identity hash cannot be empty");
        require(_publicKeyHash != bytes32(0), "Public key hash cannot be empty");
        require(identityHashToAddress[_identityHash] == address(0), "Identity hash already registered");

        uint64 currentTimestamp = uint64(block.timestamp);

        identities[msg.sender] = Identity({
            identityHash: _identityHash,
            publicKeyHash: _publicKeyHash,
            timestamp: currentTimestamp,
            isVerified: false,
            isActive: true
        });

        identityHashToAddress[_identityHash] = msg.sender;
        totalIdentities++;

        emit IdentityRegistered(msg.sender, _identityHash, currentTimestamp);
    }

    function verifyIdentity(address _user)
        external
        onlyAuthorizedVerifier
        identityExists(_user)
    {
        require(identities[_user].isActive, "Identity is not active");
        require(!identities[_user].isVerified, "Identity already verified");

        identities[_user].isVerified = true;

        emit IdentityVerified(_user, identities[_user].identityHash, msg.sender);
    }

    function revokeIdentity(address _user)
        external
        onlyAuthorizedVerifier
        identityExists(_user)
    {
        require(identities[_user].isActive, "Identity already revoked");

        identities[_user].isActive = false;

        emit IdentityRevoked(_user, identities[_user].identityHash);
    }

    function authorizeVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[_verifier], "Verifier already authorized");

        authorizedVerifiers[_verifier] = true;

        emit VerifierAuthorized(_verifier);
    }

    function revokeVerifier(address _verifier) external onlyOwner {
        require(_verifier != owner, "Cannot revoke owner");
        require(authorizedVerifiers[_verifier], "Verifier not authorized");

        authorizedVerifiers[_verifier] = false;

        emit VerifierRevoked(_verifier);
    }

    function getIdentity(address _user)
        external
        view
        returns (bytes32 identityHash, bytes32 publicKeyHash, uint64 timestamp, bool isVerified, bool isActive)
    {
        Identity memory identity = identities[_user];
        return (
            identity.identityHash,
            identity.publicKeyHash,
            identity.timestamp,
            identity.isVerified,
            identity.isActive
        );
    }

    function isIdentityVerified(address _user) external view returns (bool) {
        return identities[_user].isVerified && identities[_user].isActive;
    }

    function isVerifierAuthorized(address _verifier) external view returns (bool) {
        return authorizedVerifiers[_verifier];
    }

    function getAddressByIdentityHash(bytes32 _identityHash) external view returns (address) {
        return identityHashToAddress[_identityHash];
    }

    function getTotalIdentities() external view returns (uint256) {
        return totalIdentities;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different from current owner");

        authorizedVerifiers[_newOwner] = true;
        owner = _newOwner;
    }
}
