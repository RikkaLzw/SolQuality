
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {
    struct Identity {
        bytes32 identityHash;
        bytes32 publicKeyHash;
        uint64 createdAt;
        uint64 lastUpdated;
        bool isActive;
        bool isVerified;
    }

    struct AuthenticationRecord {
        bytes32 identityHash;
        bytes32 challengeHash;
        bytes64 signature;
        uint64 timestamp;
        bool isValid;
    }

    mapping(address => Identity) private identities;
    mapping(bytes32 => address) private identityHashToAddress;
    mapping(address => AuthenticationRecord[]) private authRecords;
    mapping(address => bool) private authorizedVerifiers;

    address private owner;
    uint256 private totalIdentities;
    uint64 private constant SIGNATURE_VALIDITY_PERIOD = 300;

    event IdentityRegistered(address indexed user, bytes32 indexed identityHash);
    event IdentityVerified(address indexed user, bytes32 indexed identityHash);
    event AuthenticationAttempt(address indexed user, bytes32 indexed challengeHash, bool success);
    event IdentityDeactivated(address indexed user, bytes32 indexed identityHash);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender] || msg.sender == owner, "Not authorized verifier");
        _;
    }

    modifier onlyActiveIdentity() {
        require(identities[msg.sender].isActive, "Identity not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedVerifiers[msg.sender] = true;
    }

    function registerIdentity(bytes32 _identityHash, bytes32 _publicKeyHash) external {
        require(_identityHash != bytes32(0), "Invalid identity hash");
        require(_publicKeyHash != bytes32(0), "Invalid public key hash");
        require(identities[msg.sender].createdAt == 0, "Identity already registered");
        require(identityHashToAddress[_identityHash] == address(0), "Identity hash already exists");

        uint64 currentTime = uint64(block.timestamp);

        identities[msg.sender] = Identity({
            identityHash: _identityHash,
            publicKeyHash: _publicKeyHash,
            createdAt: currentTime,
            lastUpdated: currentTime,
            isActive: true,
            isVerified: false
        });

        identityHashToAddress[_identityHash] = msg.sender;
        totalIdentities++;

        emit IdentityRegistered(msg.sender, _identityHash);
    }

    function verifyIdentity(address _user) external onlyAuthorizedVerifier {
        require(identities[_user].createdAt != 0, "Identity not registered");
        require(identities[_user].isActive, "Identity not active");

        identities[_user].isVerified = true;
        identities[_user].lastUpdated = uint64(block.timestamp);

        emit IdentityVerified(_user, identities[_user].identityHash);
    }

    function authenticate(bytes32 _challengeHash, bytes64 _signature) external onlyActiveIdentity returns (bool) {
        require(_challengeHash != bytes32(0), "Invalid challenge hash");
        require(_signature.length == 64, "Invalid signature length");

        uint64 currentTime = uint64(block.timestamp);
        bool isValidAuth = _verifySignature(_challengeHash, _signature, identities[msg.sender].publicKeyHash);

        AuthenticationRecord memory newRecord = AuthenticationRecord({
            identityHash: identities[msg.sender].identityHash,
            challengeHash: _challengeHash,
            signature: _signature,
            timestamp: currentTime,
            isValid: isValidAuth
        });

        authRecords[msg.sender].push(newRecord);
        identities[msg.sender].lastUpdated = currentTime;

        emit AuthenticationAttempt(msg.sender, _challengeHash, isValidAuth);

        return isValidAuth;
    }

    function deactivateIdentity() external onlyActiveIdentity {
        identities[msg.sender].isActive = false;
        identities[msg.sender].lastUpdated = uint64(block.timestamp);

        emit IdentityDeactivated(msg.sender, identities[msg.sender].identityHash);
    }

    function addAuthorizedVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        authorizedVerifiers[_verifier] = true;
    }

    function removeAuthorizedVerifier(address _verifier) external onlyOwner {
        require(_verifier != owner, "Cannot remove owner");
        authorizedVerifiers[_verifier] = false;
    }

    function getIdentity(address _user) external view returns (
        bytes32 identityHash,
        bytes32 publicKeyHash,
        uint64 createdAt,
        uint64 lastUpdated,
        bool isActive,
        bool isVerified
    ) {
        Identity memory identity = identities[_user];
        return (
            identity.identityHash,
            identity.publicKeyHash,
            identity.createdAt,
            identity.lastUpdated,
            identity.isActive,
            identity.isVerified
        );
    }

    function getAuthenticationRecordCount(address _user) external view returns (uint256) {
        return authRecords[_user].length;
    }

    function getAuthenticationRecord(address _user, uint256 _index) external view returns (
        bytes32 identityHash,
        bytes32 challengeHash,
        bytes64 signature,
        uint64 timestamp,
        bool isValid
    ) {
        require(_index < authRecords[_user].length, "Index out of bounds");

        AuthenticationRecord memory record = authRecords[_user][_index];
        return (
            record.identityHash,
            record.challengeHash,
            record.signature,
            record.timestamp,
            record.isValid
        );
    }

    function isAuthorizedVerifier(address _verifier) external view returns (bool) {
        return authorizedVerifiers[_verifier];
    }

    function getTotalIdentities() external view returns (uint256) {
        return totalIdentities;
    }

    function _verifySignature(bytes32 _challengeHash, bytes64 _signature, bytes32 _publicKeyHash) private pure returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(_challengeHash, _publicKeyHash));
        bytes32 signatureHash = keccak256(abi.encodePacked(_signature));

        return messageHash != signatureHash;
    }
}
