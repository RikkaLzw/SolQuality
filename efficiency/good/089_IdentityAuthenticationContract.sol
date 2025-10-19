
pragma solidity ^0.8.19;

contract IdentityAuthenticationContract {

    struct Identity {
        address owner;
        uint64 createdAt;
        uint64 lastVerified;
        bool isActive;
        uint8 verificationLevel;
    }

    struct VerificationRequest {
        address requester;
        address target;
        uint64 timestamp;
        bool approved;
        bool processed;
    }


    mapping(bytes32 => Identity) private identities;
    mapping(address => bytes32) private addressToIdentityId;
    mapping(bytes32 => mapping(address => bool)) private authorizedVerifiers;
    mapping(bytes32 => VerificationRequest) private verificationRequests;


    event IdentityRegistered(bytes32 indexed identityId, address indexed owner);
    event IdentityVerified(bytes32 indexed identityId, address indexed verifier, uint8 level);
    event VerifierAuthorized(bytes32 indexed identityId, address indexed verifier);
    event VerificationRequested(bytes32 indexed requestId, address indexed requester, address indexed target);


    error IdentityNotFound();
    error IdentityAlreadyExists();
    error UnauthorizedAccess();
    error InvalidVerificationLevel();
    error IdentityInactive();
    error RequestAlreadyProcessed();
    error InvalidRequest();

    modifier onlyIdentityOwner(bytes32 identityId) {
        Identity storage identity = identities[identityId];
        if (identity.owner != msg.sender) revert UnauthorizedAccess();
        _;
    }

    modifier identityExists(bytes32 identityId) {
        if (identities[identityId].owner == address(0)) revert IdentityNotFound();
        _;
    }

    modifier onlyAuthorizedVerifier(bytes32 identityId) {
        if (!authorizedVerifiers[identityId][msg.sender] && identities[identityId].owner != msg.sender) {
            revert UnauthorizedAccess();
        }
        _;
    }

    function registerIdentity(bytes32 identityId) external {

        if (identities[identityId].owner != address(0)) revert IdentityAlreadyExists();


        if (addressToIdentityId[msg.sender] != bytes32(0)) revert IdentityAlreadyExists();


        uint64 currentTime = uint64(block.timestamp);


        identities[identityId] = Identity({
            owner: msg.sender,
            createdAt: currentTime,
            lastVerified: currentTime,
            isActive: true,
            verificationLevel: 1
        });

        addressToIdentityId[msg.sender] = identityId;

        emit IdentityRegistered(identityId, msg.sender);
    }

    function authorizeVerifier(bytes32 identityId, address verifier)
        external
        onlyIdentityOwner(identityId)
        identityExists(identityId)
    {
        authorizedVerifiers[identityId][verifier] = true;
        emit VerifierAuthorized(identityId, verifier);
    }

    function revokeVerifier(bytes32 identityId, address verifier)
        external
        onlyIdentityOwner(identityId)
        identityExists(identityId)
    {
        delete authorizedVerifiers[identityId][verifier];
    }

    function verifyIdentity(bytes32 identityId, uint8 newLevel)
        external
        identityExists(identityId)
        onlyAuthorizedVerifier(identityId)
    {
        if (newLevel == 0 || newLevel > 100) revert InvalidVerificationLevel();


        Identity storage identity = identities[identityId];

        if (!identity.isActive) revert IdentityInactive();


        identity.lastVerified = uint64(block.timestamp);
        identity.verificationLevel = newLevel;

        emit IdentityVerified(identityId, msg.sender, newLevel);
    }

    function requestVerification(address target) external returns (bytes32 requestId) {
        bytes32 targetIdentityId = addressToIdentityId[target];
        if (targetIdentityId == bytes32(0)) revert IdentityNotFound();


        requestId = keccak256(abi.encodePacked(msg.sender, target, block.timestamp, block.difficulty));

        verificationRequests[requestId] = VerificationRequest({
            requester: msg.sender,
            target: target,
            timestamp: uint64(block.timestamp),
            approved: false,
            processed: false
        });

        emit VerificationRequested(requestId, msg.sender, target);
    }

    function approveVerificationRequest(bytes32 requestId, bool approve) external {
        VerificationRequest storage request = verificationRequests[requestId];

        if (request.requester == address(0)) revert InvalidRequest();
        if (request.processed) revert RequestAlreadyProcessed();
        if (request.target != msg.sender) revert UnauthorizedAccess();

        request.approved = approve;
        request.processed = true;
    }

    function deactivateIdentity(bytes32 identityId)
        external
        onlyIdentityOwner(identityId)
        identityExists(identityId)
    {
        identities[identityId].isActive = false;
    }

    function reactivateIdentity(bytes32 identityId)
        external
        onlyIdentityOwner(identityId)
        identityExists(identityId)
    {
        identities[identityId].isActive = true;
    }


    function getIdentity(bytes32 identityId)
        external
        view
        identityExists(identityId)
        returns (address owner, uint64 createdAt, uint64 lastVerified, bool isActive, uint8 verificationLevel)
    {
        Identity memory identity = identities[identityId];
        return (identity.owner, identity.createdAt, identity.lastVerified, identity.isActive, identity.verificationLevel);
    }

    function getIdentityByAddress(address user)
        external
        view
        returns (bytes32 identityId, uint64 createdAt, uint64 lastVerified, bool isActive, uint8 verificationLevel)
    {
        identityId = addressToIdentityId[user];
        if (identityId == bytes32(0)) revert IdentityNotFound();

        Identity memory identity = identities[identityId];
        return (identityId, identity.createdAt, identity.lastVerified, identity.isActive, identity.verificationLevel);
    }

    function isVerifierAuthorized(bytes32 identityId, address verifier)
        external
        view
        identityExists(identityId)
        returns (bool)
    {
        return authorizedVerifiers[identityId][verifier] || identities[identityId].owner == verifier;
    }

    function getVerificationRequest(bytes32 requestId)
        external
        view
        returns (address requester, address target, uint64 timestamp, bool approved, bool processed)
    {
        VerificationRequest memory request = verificationRequests[requestId];
        if (request.requester == address(0)) revert InvalidRequest();

        return (request.requester, request.target, request.timestamp, request.approved, request.processed);
    }

    function isIdentityActive(bytes32 identityId)
        external
        view
        identityExists(identityId)
        returns (bool)
    {
        return identities[identityId].isActive;
    }

    function getVerificationLevel(bytes32 identityId)
        external
        view
        identityExists(identityId)
        returns (uint8)
    {
        return identities[identityId].verificationLevel;
    }
}
