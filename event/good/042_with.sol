
pragma solidity ^0.8.0;


contract IdentityAuthenticationContract {

    struct Identity {
        address userAddress;
        string name;
        string email;
        bytes32 documentHash;
        bool isVerified;
        bool isActive;
        uint256 registrationTime;
        uint256 lastUpdateTime;
    }


    mapping(address => Identity) private identities;


    mapping(address => bool) public verifiedUsers;


    mapping(address => bool) public admins;


    address public owner;


    uint256 public totalUsers;


    uint256 public totalVerifiedUsers;


    event IdentityRegistered(
        address indexed user,
        string indexed name,
        uint256 indexed timestamp
    );

    event IdentityVerified(
        address indexed user,
        address indexed verifier,
        uint256 indexed timestamp
    );

    event IdentityRevoked(
        address indexed user,
        address indexed revoker,
        uint256 indexed timestamp,
        string reason
    );

    event IdentityUpdated(
        address indexed user,
        uint256 indexed timestamp
    );

    event AdminAdded(
        address indexed newAdmin,
        address indexed addedBy,
        uint256 indexed timestamp
    );

    event AdminRemoved(
        address indexed removedAdmin,
        address indexed removedBy,
        uint256 indexed timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 indexed timestamp
    );


    error UnauthorizedAccess(address caller, string requiredRole);
    error IdentityAlreadyExists(address user);
    error IdentityNotFound(address user);
    error IdentityNotVerified(address user);
    error IdentityAlreadyVerified(address user);
    error InvalidAddress(address addr);
    error InvalidInput(string parameter);
    error SelfOperationNotAllowed(string operation);


    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, "owner");
        }
        _;
    }

    modifier onlyAdmin() {
        if (!admins[msg.sender] && msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, "admin");
        }
        _;
    }

    modifier validAddress(address _addr) {
        if (_addr == address(0)) {
            revert InvalidAddress(_addr);
        }
        _;
    }

    modifier identityExists(address _user) {
        if (identities[_user].userAddress == address(0)) {
            revert IdentityNotFound(_user);
        }
        _;
    }

    modifier identityNotExists(address _user) {
        if (identities[_user].userAddress != address(0)) {
            revert IdentityAlreadyExists(_user);
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;

        emit AdminAdded(msg.sender, msg.sender, block.timestamp);
    }


    function registerIdentity(
        string calldata _name,
        string calldata _email,
        bytes32 _documentHash
    ) external identityNotExists(msg.sender) {
        if (bytes(_name).length == 0) {
            revert InvalidInput("name");
        }
        if (bytes(_email).length == 0) {
            revert InvalidInput("email");
        }
        if (_documentHash == bytes32(0)) {
            revert InvalidInput("documentHash");
        }

        identities[msg.sender] = Identity({
            userAddress: msg.sender,
            name: _name,
            email: _email,
            documentHash: _documentHash,
            isVerified: false,
            isActive: true,
            registrationTime: block.timestamp,
            lastUpdateTime: block.timestamp
        });

        totalUsers++;

        emit IdentityRegistered(msg.sender, _name, block.timestamp);
    }


    function verifyIdentity(address _user)
        external
        onlyAdmin
        validAddress(_user)
        identityExists(_user)
    {
        if (identities[_user].isVerified) {
            revert IdentityAlreadyVerified(_user);
        }
        if (!identities[_user].isActive) {
            revert InvalidInput("inactive identity");
        }

        identities[_user].isVerified = true;
        identities[_user].lastUpdateTime = block.timestamp;
        verifiedUsers[_user] = true;
        totalVerifiedUsers++;

        emit IdentityVerified(_user, msg.sender, block.timestamp);
    }


    function revokeIdentity(address _user, string calldata _reason)
        external
        onlyAdmin
        validAddress(_user)
        identityExists(_user)
    {
        if (!identities[_user].isVerified) {
            revert IdentityNotVerified(_user);
        }
        if (bytes(_reason).length == 0) {
            revert InvalidInput("reason");
        }

        identities[_user].isVerified = false;
        identities[_user].isActive = false;
        identities[_user].lastUpdateTime = block.timestamp;
        verifiedUsers[_user] = false;
        totalVerifiedUsers--;

        emit IdentityRevoked(_user, msg.sender, block.timestamp, _reason);
    }


    function updateIdentity(
        string calldata _name,
        string calldata _email,
        bytes32 _documentHash
    ) external identityExists(msg.sender) {
        if (bytes(_name).length == 0) {
            revert InvalidInput("name");
        }
        if (bytes(_email).length == 0) {
            revert InvalidInput("email");
        }
        if (_documentHash == bytes32(0)) {
            revert InvalidInput("documentHash");
        }
        if (!identities[msg.sender].isActive) {
            revert InvalidInput("inactive identity");
        }

        Identity storage identity = identities[msg.sender];
        identity.name = _name;
        identity.email = _email;
        identity.documentHash = _documentHash;
        identity.lastUpdateTime = block.timestamp;


        if (identity.isVerified) {
            identity.isVerified = false;
            verifiedUsers[msg.sender] = false;
            totalVerifiedUsers--;
        }

        emit IdentityUpdated(msg.sender, block.timestamp);
    }


    function addAdmin(address _admin)
        external
        onlyOwner
        validAddress(_admin)
    {
        if (admins[_admin]) {
            revert InvalidInput("already admin");
        }

        admins[_admin] = true;
        emit AdminAdded(_admin, msg.sender, block.timestamp);
    }


    function removeAdmin(address _admin)
        external
        onlyOwner
        validAddress(_admin)
    {
        if (_admin == owner) {
            revert SelfOperationNotAllowed("remove owner as admin");
        }
        if (!admins[_admin]) {
            revert InvalidInput("not an admin");
        }

        admins[_admin] = false;
        emit AdminRemoved(_admin, msg.sender, block.timestamp);
    }


    function transferOwnership(address _newOwner)
        external
        onlyOwner
        validAddress(_newOwner)
    {
        if (_newOwner == owner) {
            revert SelfOperationNotAllowed("transfer to same owner");
        }

        address previousOwner = owner;
        owner = _newOwner;
        admins[_newOwner] = true;

        emit OwnershipTransferred(previousOwner, _newOwner, block.timestamp);
        emit AdminAdded(_newOwner, previousOwner, block.timestamp);
    }


    function getIdentity(address _user)
        external
        view
        identityExists(_user)
        returns (Identity memory)
    {
        return identities[_user];
    }


    function isVerified(address _user) external view returns (bool) {
        return verifiedUsers[_user];
    }


    function hasIdentity(address _user) external view returns (bool) {
        return identities[_user].userAddress != address(0);
    }


    function isActive(address _user) external view returns (bool) {
        return identities[_user].isActive;
    }


    function getStats() external view returns (uint256, uint256) {
        return (totalUsers, totalVerifiedUsers);
    }
}
