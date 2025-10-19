
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract IdentityAuthenticationContract is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;


    uint256 public constant MAX_IDENTITY_LENGTH = 100;
    uint256 public constant MIN_IDENTITY_LENGTH = 3;
    uint256 public constant VERIFICATION_EXPIRY = 30 days;
    uint256 public constant MAX_VERIFICATION_ATTEMPTS = 3;


    enum IdentityStatus {
        Unregistered,
        Pending,
        Verified,
        Suspended,
        Revoked
    }


    struct Identity {
        string identityHash;
        address owner;
        IdentityStatus status;
        uint256 registrationTime;
        uint256 verificationTime;
        uint256 expiryTime;
        uint256 verificationAttempts;
        bytes32[] documentHashes;
        mapping(address => bool) authorizedVerifiers;
    }


    struct Verifier {
        bool isActive;
        string name;
        uint256 registrationTime;
        uint256 verificationsCount;
    }


    mapping(address => Identity) private identities;
    mapping(string => address) private identityHashToAddress;
    mapping(address => Verifier) private verifiers;

    address[] private registeredUsers;
    address[] private authorizedVerifiers;

    uint256 private totalIdentities;
    uint256 private totalVerifiedIdentities;


    event IdentityRegistered(address indexed user, string identityHash, uint256 timestamp);
    event IdentityVerified(address indexed user, address indexed verifier, uint256 timestamp);
    event IdentityStatusChanged(address indexed user, IdentityStatus oldStatus, IdentityStatus newStatus);
    event VerifierAdded(address indexed verifier, string name, uint256 timestamp);
    event VerifierRemoved(address indexed verifier, uint256 timestamp);
    event DocumentAdded(address indexed user, bytes32 documentHash, uint256 timestamp);
    event VerificationExpired(address indexed user, uint256 timestamp);


    modifier onlyRegisteredUser() {
        require(identities[msg.sender].owner == msg.sender, "User not registered");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(verifiers[msg.sender].isActive, "Not an authorized verifier");
        _;
    }

    modifier onlyValidIdentity(address user) {
        require(identities[user].owner == user, "Invalid identity");
        _;
    }

    modifier onlyValidStatus(address user, IdentityStatus requiredStatus) {
        require(identities[user].status == requiredStatus, "Invalid identity status");
        _;
    }

    modifier validIdentityHash(string memory _identityHash) {
        require(
            bytes(_identityHash).length >= MIN_IDENTITY_LENGTH &&
            bytes(_identityHash).length <= MAX_IDENTITY_LENGTH,
            "Invalid identity hash length"
        );
        require(identityHashToAddress[_identityHash] == address(0), "Identity hash already exists");
        _;
    }

    constructor() {}


    function registerIdentity(string memory _identityHash)
        external
        validIdentityHash(_identityHash)
        nonReentrant
    {
        require(identities[msg.sender].owner == address(0), "Identity already registered");

        Identity storage newIdentity = identities[msg.sender];
        newIdentity.identityHash = _identityHash;
        newIdentity.owner = msg.sender;
        newIdentity.status = IdentityStatus.Pending;
        newIdentity.registrationTime = block.timestamp;
        newIdentity.verificationAttempts = 0;

        identityHashToAddress[_identityHash] = msg.sender;
        registeredUsers.push(msg.sender);
        totalIdentities++;

        emit IdentityRegistered(msg.sender, _identityHash, block.timestamp);
    }


    function addVerifier(address _verifier, string memory _name)
        external
        onlyOwner
    {
        require(_verifier != address(0), "Invalid verifier address");
        require(!verifiers[_verifier].isActive, "Verifier already exists");
        require(bytes(_name).length > 0, "Verifier name cannot be empty");

        verifiers[_verifier] = Verifier({
            isActive: true,
            name: _name,
            registrationTime: block.timestamp,
            verificationsCount: 0
        });

        authorizedVerifiers.push(_verifier);

        emit VerifierAdded(_verifier, _name, block.timestamp);
    }


    function removeVerifier(address _verifier)
        external
        onlyOwner
    {
        require(verifiers[_verifier].isActive, "Verifier not found");

        verifiers[_verifier].isActive = false;
        _removeFromVerifiersList(_verifier);

        emit VerifierRemoved(_verifier, block.timestamp);
    }


    function verifyIdentity(address _user)
        external
        onlyAuthorizedVerifier
        onlyValidIdentity(_user)
        onlyValidStatus(_user, IdentityStatus.Pending)
        nonReentrant
    {
        Identity storage identity = identities[_user];

        require(
            identity.verificationAttempts < MAX_VERIFICATION_ATTEMPTS,
            "Maximum verification attempts exceeded"
        );

        identity.verificationAttempts++;

        if (_canVerifyIdentity(_user)) {
            IdentityStatus oldStatus = identity.status;
            identity.status = IdentityStatus.Verified;
            identity.verificationTime = block.timestamp;
            identity.expiryTime = block.timestamp + VERIFICATION_EXPIRY;
            identity.authorizedVerifiers[msg.sender] = true;

            verifiers[msg.sender].verificationsCount++;
            totalVerifiedIdentities++;

            emit IdentityVerified(_user, msg.sender, block.timestamp);
            emit IdentityStatusChanged(_user, oldStatus, IdentityStatus.Verified);
        }
    }


    function addDocument(bytes32 _documentHash)
        external
        onlyRegisteredUser
        nonReentrant
    {
        require(_documentHash != bytes32(0), "Invalid document hash");

        identities[msg.sender].documentHashes.push(_documentHash);

        emit DocumentAdded(msg.sender, _documentHash, block.timestamp);
    }


    function suspendIdentity(address _user)
        external
        onlyOwner
        onlyValidIdentity(_user)
    {
        IdentityStatus oldStatus = identities[_user].status;
        require(oldStatus != IdentityStatus.Suspended, "Identity already suspended");

        identities[_user].status = IdentityStatus.Suspended;

        emit IdentityStatusChanged(_user, oldStatus, IdentityStatus.Suspended);
    }


    function revokeIdentity(address _user)
        external
        onlyOwner
        onlyValidIdentity(_user)
    {
        IdentityStatus oldStatus = identities[_user].status;
        require(oldStatus != IdentityStatus.Revoked, "Identity already revoked");

        identities[_user].status = IdentityStatus.Revoked;

        if (oldStatus == IdentityStatus.Verified) {
            totalVerifiedIdentities--;
        }

        emit IdentityStatusChanged(_user, oldStatus, IdentityStatus.Revoked);
    }


    function renewVerification()
        external
        onlyRegisteredUser
        onlyValidStatus(msg.sender, IdentityStatus.Verified)
        nonReentrant
    {
        Identity storage identity = identities[msg.sender];
        require(block.timestamp >= identity.expiryTime, "Verification not yet expired");

        identity.status = IdentityStatus.Pending;
        identity.verificationAttempts = 0;
        identity.expiryTime = 0;

        totalVerifiedIdentities--;

        emit IdentityStatusChanged(msg.sender, IdentityStatus.Verified, IdentityStatus.Pending);
    }


    function checkAndUpdateExpiredVerification(address _user)
        external
        onlyValidIdentity(_user)
    {
        Identity storage identity = identities[_user];

        if (identity.status == IdentityStatus.Verified &&
            block.timestamp > identity.expiryTime) {

            identity.status = IdentityStatus.Pending;
            identity.verificationAttempts = 0;
            totalVerifiedIdentities--;

            emit VerificationExpired(_user, block.timestamp);
            emit IdentityStatusChanged(_user, IdentityStatus.Verified, IdentityStatus.Pending);
        }
    }


    function getIdentity(address _user)
        external
        view
        returns (
            string memory identityHash,
            IdentityStatus status,
            uint256 registrationTime,
            uint256 verificationTime,
            uint256 expiryTime,
            uint256 verificationAttempts
        )
    {
        Identity storage identity = identities[_user];
        return (
            identity.identityHash,
            identity.status,
            identity.registrationTime,
            identity.verificationTime,
            identity.expiryTime,
            identity.verificationAttempts
        );
    }

    function getVerifier(address _verifier)
        external
        view
        returns (
            bool isActive,
            string memory name,
            uint256 registrationTime,
            uint256 verificationsCount
        )
    {
        Verifier storage verifier = verifiers[_verifier];
        return (
            verifier.isActive,
            verifier.name,
            verifier.registrationTime,
            verifier.verificationsCount
        );
    }

    function isIdentityVerified(address _user) external view returns (bool) {
        Identity storage identity = identities[_user];
        return identity.status == IdentityStatus.Verified &&
               block.timestamp <= identity.expiryTime;
    }

    function getDocumentHashes(address _user)
        external
        view
        returns (bytes32[] memory)
    {
        return identities[_user].documentHashes;
    }

    function getTotalIdentities() external view returns (uint256) {
        return totalIdentities;
    }

    function getTotalVerifiedIdentities() external view returns (uint256) {
        return totalVerifiedIdentities;
    }

    function getRegisteredUsers() external view returns (address[] memory) {
        return registeredUsers;
    }

    function getAuthorizedVerifiers() external view returns (address[] memory) {
        return authorizedVerifiers;
    }


    function _canVerifyIdentity(address _user) internal view returns (bool) {

        return identities[_user].owner == _user;
    }

    function _removeFromVerifiersList(address _verifier) internal {
        for (uint256 i = 0; i < authorizedVerifiers.length; i++) {
            if (authorizedVerifiers[i] == _verifier) {
                authorizedVerifiers[i] = authorizedVerifiers[authorizedVerifiers.length - 1];
                authorizedVerifiers.pop();
                break;
            }
        }
    }
}
