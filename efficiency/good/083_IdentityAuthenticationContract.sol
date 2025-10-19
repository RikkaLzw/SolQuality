
pragma solidity ^0.8.0;

contract IdentityAuthenticationContract {

    struct Identity {
        address owner;
        uint96 timestamp;
        bool isActive;
        uint8 authLevel;
    }

    struct AuthRequest {
        address requester;
        uint96 expiry;
        bool approved;
        uint8 requestedLevel;
    }


    mapping(bytes32 => Identity) private identities;
    mapping(address => bytes32[]) private userIdentities;
    mapping(bytes32 => AuthRequest[]) private authRequests;
    mapping(address => mapping(bytes32 => bool)) private authorizedAccess;


    mapping(address => uint256) private userIdentityCount;


    event IdentityRegistered(bytes32 indexed identityId, address indexed owner, uint8 authLevel);
    event IdentityRevoked(bytes32 indexed identityId, address indexed owner);
    event AuthenticationRequested(bytes32 indexed identityId, address indexed requester, uint8 level);
    event AuthenticationApproved(bytes32 indexed identityId, address indexed requester);
    event AccessGranted(address indexed user, bytes32 indexed identityId);


    modifier onlyIdentityOwner(bytes32 identityId) {
        require(identities[identityId].owner == msg.sender, "Not identity owner");
        _;
    }

    modifier validIdentity(bytes32 identityId) {
        require(identities[identityId].owner != address(0), "Identity not found");
        require(identities[identityId].isActive, "Identity inactive");
        _;
    }


    function registerIdentity(
        string calldata identityData,
        uint8 authLevel
    ) external returns (bytes32 identityId) {

        identityId = keccak256(abi.encodePacked(msg.sender, identityData, block.timestamp));


        require(identities[identityId].owner == address(0), "Identity already exists");


        uint96 currentTime = uint96(block.timestamp);


        Identity memory newIdentity = Identity({
            owner: msg.sender,
            timestamp: currentTime,
            isActive: true,
            authLevel: authLevel
        });


        identities[identityId] = newIdentity;


        userIdentities[msg.sender].push(identityId);


        unchecked {
            userIdentityCount[msg.sender]++;
        }

        emit IdentityRegistered(identityId, msg.sender, authLevel);
    }


    function requestAuthentication(
        bytes32 identityId,
        uint8 requestedLevel,
        uint96 duration
    ) external validIdentity(identityId) {

        Identity storage identity = identities[identityId];

        require(requestedLevel <= identity.authLevel, "Insufficient auth level");


        uint96 expiry = uint96(block.timestamp) + duration;


        AuthRequest memory request = AuthRequest({
            requester: msg.sender,
            expiry: expiry,
            approved: false,
            requestedLevel: requestedLevel
        });


        authRequests[identityId].push(request);

        emit AuthenticationRequested(identityId, msg.sender, requestedLevel);
    }


    function approveAuthentication(
        bytes32 identityId,
        uint256 requestIndex
    ) external onlyIdentityOwner(identityId) validIdentity(identityId) {

        AuthRequest[] storage requests = authRequests[identityId];
        require(requestIndex < requests.length, "Invalid request index");


        AuthRequest storage request = requests[requestIndex];
        require(!request.approved, "Already approved");
        require(block.timestamp < request.expiry, "Request expired");


        request.approved = true;


        authorizedAccess[request.requester][identityId] = true;

        emit AuthenticationApproved(identityId, request.requester);
        emit AccessGranted(request.requester, identityId);
    }


    function revokeIdentity(bytes32 identityId) external onlyIdentityOwner(identityId) {

        Identity storage identity = identities[identityId];
        identity.isActive = false;

        emit IdentityRevoked(identityId, msg.sender);
    }


    function batchVerifyIdentities(
        bytes32[] calldata identityIds,
        address user
    ) external view returns (bool[] memory results) {
        uint256 length = identityIds.length;
        results = new bool[](length);


        unchecked {
            for (uint256 i = 0; i < length; i++) {
                results[i] = verifyIdentity(identityIds[i], user);
            }
        }
    }


    function verifyIdentity(bytes32 identityId, address user) public view returns (bool) {
        return identities[identityId].isActive && authorizedAccess[user][identityId];
    }


    function getIdentityInfo(bytes32 identityId) external view returns (
        address owner,
        uint96 timestamp,
        bool isActive,
        uint8 authLevel
    ) {

        Identity storage identity = identities[identityId];
        return (identity.owner, identity.timestamp, identity.isActive, identity.authLevel);
    }


    function getUserIdentityCount(address user) external view returns (uint256) {
        return userIdentityCount[user];
    }


    function getUserIdentities(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory identityIds) {
        bytes32[] storage userIds = userIdentities[user];
        uint256 totalCount = userIds.length;

        if (offset >= totalCount) {
            return new bytes32[](0);
        }

        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }

        uint256 resultLength = end - offset;
        identityIds = new bytes32[](resultLength);

        unchecked {
            for (uint256 i = 0; i < resultLength; i++) {
                identityIds[i] = userIds[offset + i];
            }
        }
    }


    function getPendingRequestsCount(bytes32 identityId) external view returns (uint256 count) {
        AuthRequest[] storage requests = authRequests[identityId];
        uint256 length = requests.length;

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                if (!requests[i].approved && block.timestamp < requests[i].expiry) {
                    count++;
                }
            }
        }
    }


    function cleanExpiredRequests(bytes32 identityId) external onlyIdentityOwner(identityId) {
        AuthRequest[] storage requests = authRequests[identityId];
        uint256 length = requests.length;
        uint256 writeIndex = 0;


        unchecked {
            for (uint256 i = 0; i < length; i++) {
                if (block.timestamp < requests[i].expiry) {
                    if (writeIndex != i) {
                        requests[writeIndex] = requests[i];
                    }
                    writeIndex++;
                }
            }
        }


        while (requests.length > writeIndex) {
            requests.pop();
        }
    }
}
