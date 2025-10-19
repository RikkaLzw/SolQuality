
pragma solidity ^0.8.0;


contract IdentityAuthenticationContract {


    enum IdentityStatus {
        Unverified,
        Pending,
        Verified,
        Suspended,
        Revoked
    }


    struct UserIdentity {
        address userAddress;
        string identityHash;
        IdentityStatus status;
        uint256 verificationTime;
        uint256 expirationTime;
        address verifier;
        bool isActive;
    }


    address public contractOwner;
    mapping(address => UserIdentity) public userIdentities;
    mapping(address => bool) public authorizedVerifiers;
    mapping(string => address) public identityHashToAddress;

    uint256 public totalVerifiedUsers;
    uint256 public constant IDENTITY_VALIDITY_PERIOD = 365 days;


    event IdentityRegistered(
        address indexed userAddress,
        string identityHash,
        uint256 timestamp
    );

    event IdentityVerified(
        address indexed userAddress,
        address indexed verifier,
        uint256 timestamp
    );

    event IdentityStatusChanged(
        address indexed userAddress,
        IdentityStatus oldStatus,
        IdentityStatus newStatus,
        uint256 timestamp
    );

    event VerifierAuthorized(
        address indexed verifier,
        uint256 timestamp
    );

    event VerifierRevoked(
        address indexed verifier,
        uint256 timestamp
    );

    event IdentityRenewed(
        address indexed userAddress,
        uint256 newExpirationTime,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender], "Only authorized verifiers can perform this action");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address provided");
        _;
    }

    modifier identityExists(address _userAddress) {
        require(userIdentities[_userAddress].isActive, "User identity does not exist");
        _;
    }

    modifier notExpired(address _userAddress) {
        require(
            userIdentities[_userAddress].expirationTime > block.timestamp,
            "User identity has expired"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        authorizedVerifiers[msg.sender] = true;

        emit VerifierAuthorized(msg.sender, block.timestamp);
    }


    function registerIdentity(string memory _identityHash)
        external
        validAddress(msg.sender)
    {
        require(bytes(_identityHash).length > 0, "Identity hash cannot be empty");
        require(!userIdentities[msg.sender].isActive, "User identity already exists");
        require(identityHashToAddress[_identityHash] == address(0), "Identity hash already registered");


        userIdentities[msg.sender] = UserIdentity({
            userAddress: msg.sender,
            identityHash: _identityHash,
            status: IdentityStatus.Pending,
            verificationTime: 0,
            expirationTime: 0,
            verifier: address(0),
            isActive: true
        });


        identityHashToAddress[_identityHash] = msg.sender;

        emit IdentityRegistered(msg.sender, _identityHash, block.timestamp);
    }


    function verifyIdentity(address _userAddress)
        external
        onlyAuthorizedVerifier
        validAddress(_userAddress)
        identityExists(_userAddress)
    {
        UserIdentity storage identity = userIdentities[_userAddress];
        require(identity.status == IdentityStatus.Pending, "Identity is not in pending status");


        IdentityStatus oldStatus = identity.status;
        identity.status = IdentityStatus.Verified;
        identity.verificationTime = block.timestamp;
        identity.expirationTime = block.timestamp + IDENTITY_VALIDITY_PERIOD;
        identity.verifier = msg.sender;


        totalVerifiedUsers++;

        emit IdentityVerified(_userAddress, msg.sender, block.timestamp);
        emit IdentityStatusChanged(_userAddress, oldStatus, IdentityStatus.Verified, block.timestamp);
    }


    function changeIdentityStatus(address _userAddress, IdentityStatus _newStatus)
        external
        onlyAuthorizedVerifier
        validAddress(_userAddress)
        identityExists(_userAddress)
    {
        UserIdentity storage identity = userIdentities[_userAddress];
        require(identity.status != _newStatus, "New status is the same as current status");

        IdentityStatus oldStatus = identity.status;


        if (oldStatus == IdentityStatus.Verified && _newStatus != IdentityStatus.Verified) {
            totalVerifiedUsers--;
        }

        else if (oldStatus != IdentityStatus.Verified && _newStatus == IdentityStatus.Verified) {
            totalVerifiedUsers++;
            identity.verificationTime = block.timestamp;
            identity.expirationTime = block.timestamp + IDENTITY_VALIDITY_PERIOD;
        }

        identity.status = _newStatus;

        emit IdentityStatusChanged(_userAddress, oldStatus, _newStatus, block.timestamp);
    }


    function renewIdentity(address _userAddress)
        external
        onlyAuthorizedVerifier
        validAddress(_userAddress)
        identityExists(_userAddress)
    {
        UserIdentity storage identity = userIdentities[_userAddress];
        require(identity.status == IdentityStatus.Verified, "Identity must be verified to renew");


        identity.expirationTime = block.timestamp + IDENTITY_VALIDITY_PERIOD;

        emit IdentityRenewed(_userAddress, identity.expirationTime, block.timestamp);
    }


    function authorizeVerifier(address _verifier)
        external
        onlyOwner
        validAddress(_verifier)
    {
        require(!authorizedVerifiers[_verifier], "Verifier is already authorized");

        authorizedVerifiers[_verifier] = true;

        emit VerifierAuthorized(_verifier, block.timestamp);
    }


    function revokeVerifier(address _verifier)
        external
        onlyOwner
        validAddress(_verifier)
    {
        require(authorizedVerifiers[_verifier], "Verifier is not authorized");
        require(_verifier != contractOwner, "Cannot revoke owner's verifier status");

        authorizedVerifiers[_verifier] = false;

        emit VerifierRevoked(_verifier, block.timestamp);
    }


    function isIdentityValid(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (bool isValid)
    {
        UserIdentity memory identity = userIdentities[_userAddress];

        return (
            identity.isActive &&
            identity.status == IdentityStatus.Verified &&
            identity.expirationTime > block.timestamp
        );
    }


    function getUserIdentity(address _userAddress)
        external
        view
        validAddress(_userAddress)
        returns (UserIdentity memory identity)
    {
        return userIdentities[_userAddress];
    }


    function getUserByIdentityHash(string memory _identityHash)
        external
        view
        returns (address userAddress)
    {
        require(bytes(_identityHash).length > 0, "Identity hash cannot be empty");
        return identityHashToAddress[_identityHash];
    }


    function isAuthorizedVerifier(address _verifier)
        external
        view
        validAddress(_verifier)
        returns (bool isAuthorized)
    {
        return authorizedVerifiers[_verifier];
    }


    function getContractStats()
        external
        view
        returns (
            address owner,
            uint256 verifiedCount,
            uint256 validityPeriod
        )
    {
        return (
            contractOwner,
            totalVerifiedUsers,
            IDENTITY_VALIDITY_PERIOD
        );
    }


    function transferOwnership(address _newOwner)
        external
        onlyOwner
        validAddress(_newOwner)
    {
        require(_newOwner != contractOwner, "New owner is the same as current owner");


        if (!authorizedVerifiers[_newOwner]) {
            authorizedVerifiers[_newOwner] = true;
            emit VerifierAuthorized(_newOwner, block.timestamp);
        }

        contractOwner = _newOwner;
    }
}
