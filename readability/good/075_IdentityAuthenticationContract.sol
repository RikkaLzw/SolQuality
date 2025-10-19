
pragma solidity ^0.8.0;


contract IdentityAuthenticationContract {


    enum IdentityStatus {
        Unverified,
        Pending,
        Verified,
        Suspended,
        Revoked
    }


    struct IdentityInfo {
        string fullName;
        string documentHash;
        uint256 verificationTimestamp;
        IdentityStatus status;
        address verifier;
        bool isActive;
    }


    address public contractOwner;


    mapping(address => bool) public authorizedVerifiers;


    mapping(address => IdentityInfo) public userIdentities;


    address[] public registeredUsers;


    address[] public verifiersList;


    event IdentityRegistered(
        address indexed userAddress,
        string fullName,
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

    event VerifierAdded(
        address indexed verifier,
        uint256 timestamp
    );

    event VerifierRemoved(
        address indexed verifier,
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


    modifier userExists(address userAddress) {
        require(userIdentities[userAddress].isActive, "User is not registered");
        _;
    }


    modifier userNotExists(address userAddress) {
        require(!userIdentities[userAddress].isActive, "User is already registered");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        authorizedVerifiers[msg.sender] = true;
        verifiersList.push(msg.sender);
    }


    function registerIdentity(
        string memory fullName,
        string memory documentHash
    ) external userNotExists(msg.sender) {
        require(bytes(fullName).length > 0, "Full name cannot be empty");
        require(bytes(documentHash).length > 0, "Document hash cannot be empty");

        userIdentities[msg.sender] = IdentityInfo({
            fullName: fullName,
            documentHash: documentHash,
            verificationTimestamp: 0,
            status: IdentityStatus.Pending,
            verifier: address(0),
            isActive: true
        });

        registeredUsers.push(msg.sender);

        emit IdentityRegistered(msg.sender, fullName, block.timestamp);
    }


    function verifyIdentity(address userAddress)
        external
        onlyAuthorizedVerifier
        userExists(userAddress)
    {
        require(
            userIdentities[userAddress].status == IdentityStatus.Pending,
            "Identity is not in pending status"
        );

        IdentityStatus oldStatus = userIdentities[userAddress].status;

        userIdentities[userAddress].status = IdentityStatus.Verified;
        userIdentities[userAddress].verifier = msg.sender;
        userIdentities[userAddress].verificationTimestamp = block.timestamp;

        emit IdentityVerified(userAddress, msg.sender, block.timestamp);
        emit IdentityStatusChanged(userAddress, oldStatus, IdentityStatus.Verified, block.timestamp);
    }


    function changeIdentityStatus(
        address userAddress,
        IdentityStatus newStatus
    ) external onlyAuthorizedVerifier userExists(userAddress) {
        require(newStatus != IdentityStatus.Unverified, "Cannot set status to Unverified");

        IdentityStatus oldStatus = userIdentities[userAddress].status;
        require(oldStatus != newStatus, "Status is already set to the specified value");

        userIdentities[userAddress].status = newStatus;

        emit IdentityStatusChanged(userAddress, oldStatus, newStatus, block.timestamp);
    }


    function addAuthorizedVerifier(address verifierAddress) external onlyOwner {
        require(verifierAddress != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[verifierAddress], "Verifier is already authorized");

        authorizedVerifiers[verifierAddress] = true;
        verifiersList.push(verifierAddress);

        emit VerifierAdded(verifierAddress, block.timestamp);
    }


    function removeAuthorizedVerifier(address verifierAddress) external onlyOwner {
        require(verifierAddress != contractOwner, "Cannot remove contract owner as verifier");
        require(authorizedVerifiers[verifierAddress], "Verifier is not authorized");

        authorizedVerifiers[verifierAddress] = false;


        for (uint256 i = 0; i < verifiersList.length; i++) {
            if (verifiersList[i] == verifierAddress) {
                verifiersList[i] = verifiersList[verifiersList.length - 1];
                verifiersList.pop();
                break;
            }
        }

        emit VerifierRemoved(verifierAddress, block.timestamp);
    }


    function isIdentityVerified(address userAddress) external view returns (bool) {
        return userIdentities[userAddress].isActive &&
               userIdentities[userAddress].status == IdentityStatus.Verified;
    }


    function getIdentityInfo(address userAddress)
        external
        view
        userExists(userAddress)
        returns (
            string memory fullName,
            string memory documentHash,
            uint256 verificationTimestamp,
            IdentityStatus status,
            address verifier
        )
    {
        IdentityInfo memory identity = userIdentities[userAddress];
        return (
            identity.fullName,
            identity.documentHash,
            identity.verificationTimestamp,
            identity.status,
            identity.verifier
        );
    }


    function getRegisteredUsersCount() external view returns (uint256) {
        return registeredUsers.length;
    }


    function getVerifiersCount() external view returns (uint256) {
        return verifiersList.length;
    }


    function getRegisteredUserByIndex(uint256 index) external view returns (address) {
        require(index < registeredUsers.length, "Index out of bounds");
        return registeredUsers[index];
    }


    function getVerifierByIndex(uint256 index) external view returns (address) {
        require(index < verifiersList.length, "Index out of bounds");
        return verifiersList[index];
    }


    function updateDocumentHash(string memory newDocumentHash)
        external
        userExists(msg.sender)
    {
        require(bytes(newDocumentHash).length > 0, "Document hash cannot be empty");
        require(
            userIdentities[msg.sender].status != IdentityStatus.Verified,
            "Cannot update document hash for verified identity"
        );

        userIdentities[msg.sender].documentHash = newDocumentHash;
        userIdentities[msg.sender].status = IdentityStatus.Pending;
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != contractOwner, "New owner is the same as current owner");


        if (verifiersList.length > 1) {
            authorizedVerifiers[contractOwner] = false;
            for (uint256 i = 0; i < verifiersList.length; i++) {
                if (verifiersList[i] == contractOwner) {
                    verifiersList[i] = verifiersList[verifiersList.length - 1];
                    verifiersList.pop();
                    break;
                }
            }
        }


        contractOwner = newOwner;


        if (!authorizedVerifiers[newOwner]) {
            authorizedVerifiers[newOwner] = true;
            verifiersList.push(newOwner);
        }
    }
}
