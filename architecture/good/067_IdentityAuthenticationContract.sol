
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract IdentityAuthenticationContract is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;


    uint256 public constant MAX_VERIFICATION_ATTEMPTS = 3;
    uint256 public constant VERIFICATION_TIMEOUT = 24 hours;
    uint256 public constant MIN_STAKE_AMOUNT = 0.01 ether;


    enum VerificationStatus {
        Pending,
        Verified,
        Rejected,
        Expired
    }

    enum IdentityLevel {
        Basic,
        Standard,
        Premium
    }


    struct Identity {
        address user;
        bytes32 identityHash;
        VerificationStatus status;
        IdentityLevel level;
        uint256 verificationTime;
        uint256 expirationTime;
        uint256 attemptCount;
        bool isActive;
    }

    struct Verifier {
        address verifierAddress;
        bool isAuthorized;
        uint256 reputation;
        uint256 totalVerifications;
        mapping(address => bool) verifiedUsers;
    }


    mapping(address => Identity) private identities;
    mapping(address => Verifier) private verifiers;
    mapping(bytes32 => address) private hashToUser;
    mapping(address => uint256) private userStakes;

    address[] private verifierList;
    address[] private verifiedUsers;

    uint256 private totalStaked;
    bool private contractPaused;


    event IdentityRegistered(address indexed user, bytes32 identityHash, IdentityLevel level);
    event IdentityVerified(address indexed user, address indexed verifier, VerificationStatus status);
    event VerifierAuthorized(address indexed verifier, uint256 reputation);
    event VerifierRevoked(address indexed verifier);
    event StakeDeposited(address indexed user, uint256 amount);
    event StakeWithdrawn(address indexed user, uint256 amount);
    event ContractPaused(bool paused);


    modifier onlyAuthorizedVerifier() {
        require(verifiers[msg.sender].isAuthorized, "Not authorized verifier");
        _;
    }

    modifier onlyRegisteredUser() {
        require(identities[msg.sender].user != address(0), "User not registered");
        _;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier hasMinimumStake() {
        require(userStakes[msg.sender] >= MIN_STAKE_AMOUNT, "Insufficient stake");
        _;
    }

    constructor() {
        contractPaused = false;
    }


    function registerIdentity(
        bytes32 _identityHash,
        IdentityLevel _level,
        bytes memory _signature
    )
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(identities[msg.sender].user == address(0), "Identity already registered");
        require(hashToUser[_identityHash] == address(0), "Identity hash already exists");
        require(msg.value >= MIN_STAKE_AMOUNT, "Insufficient stake amount");
        require(_verifySignature(_identityHash, _signature), "Invalid signature");

        identities[msg.sender] = Identity({
            user: msg.sender,
            identityHash: _identityHash,
            status: VerificationStatus.Pending,
            level: _level,
            verificationTime: 0,
            expirationTime: block.timestamp + VERIFICATION_TIMEOUT,
            attemptCount: 0,
            isActive: true
        });

        hashToUser[_identityHash] = msg.sender;
        userStakes[msg.sender] += msg.value;
        totalStaked += msg.value;

        emit IdentityRegistered(msg.sender, _identityHash, _level);
        emit StakeDeposited(msg.sender, msg.value);
    }


    function verifyIdentity(
        address _user,
        bool _approved
    )
        external
        onlyAuthorizedVerifier
        whenNotPaused
        validAddress(_user)
    {
        Identity storage identity = identities[_user];
        require(identity.user != address(0), "Identity not found");
        require(identity.status == VerificationStatus.Pending, "Identity not pending verification");
        require(block.timestamp <= identity.expirationTime, "Verification expired");
        require(!verifiers[msg.sender].verifiedUsers[_user], "Already verified by this verifier");

        identity.attemptCount++;
        verifiers[msg.sender].verifiedUsers[_user] = true;
        verifiers[msg.sender].totalVerifications++;

        if (_approved) {
            identity.status = VerificationStatus.Verified;
            identity.verificationTime = block.timestamp;
            identity.expirationTime = _calculateExpirationTime(identity.level);
            verifiedUsers.push(_user);
            _updateVerifierReputation(msg.sender, true);
        } else {
            if (identity.attemptCount >= MAX_VERIFICATION_ATTEMPTS) {
                identity.status = VerificationStatus.Rejected;
                identity.isActive = false;
            }
            _updateVerifierReputation(msg.sender, false);
        }

        emit IdentityVerified(_user, msg.sender, identity.status);
    }


    function authorizeVerifier(
        address _verifier,
        uint256 _initialReputation
    )
        external
        onlyOwner
        validAddress(_verifier)
    {
        require(!verifiers[_verifier].isAuthorized, "Verifier already authorized");

        verifiers[_verifier] = Verifier({
            verifierAddress: _verifier,
            isAuthorized: true,
            reputation: _initialReputation,
            totalVerifications: 0
        });

        verifierList.push(_verifier);

        emit VerifierAuthorized(_verifier, _initialReputation);
    }


    function revokeVerifier(address _verifier)
        external
        onlyOwner
        validAddress(_verifier)
    {
        require(verifiers[_verifier].isAuthorized, "Verifier not authorized");

        verifiers[_verifier].isAuthorized = false;
        _removeFromVerifierList(_verifier);

        emit VerifierRevoked(_verifier);
    }


    function depositStake()
        external
        payable
        onlyRegisteredUser
        whenNotPaused
    {
        require(msg.value > 0, "Invalid stake amount");

        userStakes[msg.sender] += msg.value;
        totalStaked += msg.value;

        emit StakeDeposited(msg.sender, msg.value);
    }


    function withdrawStake(uint256 _amount)
        external
        onlyRegisteredUser
        whenNotPaused
        nonReentrant
    {
        require(_amount > 0, "Invalid withdrawal amount");
        require(userStakes[msg.sender] >= _amount, "Insufficient stake balance");
        require(userStakes[msg.sender] - _amount >= MIN_STAKE_AMOUNT, "Cannot withdraw below minimum stake");

        Identity storage identity = identities[msg.sender];
        require(identity.status == VerificationStatus.Verified, "Identity not verified");

        userStakes[msg.sender] -= _amount;
        totalStaked -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");

        emit StakeWithdrawn(msg.sender, _amount);
    }


    function updateIdentityLevel(IdentityLevel _newLevel)
        external
        onlyRegisteredUser
        hasMinimumStake
        whenNotPaused
    {
        Identity storage identity = identities[msg.sender];
        require(identity.status == VerificationStatus.Verified, "Identity not verified");
        require(identity.level != _newLevel, "Same level");

        identity.level = _newLevel;
        identity.expirationTime = _calculateExpirationTime(_newLevel);
    }


    function renewIdentity()
        external
        onlyRegisteredUser
        hasMinimumStake
        whenNotPaused
    {
        Identity storage identity = identities[msg.sender];
        require(identity.status == VerificationStatus.Verified, "Identity not verified");
        require(block.timestamp >= identity.expirationTime - 7 days, "Too early to renew");

        identity.expirationTime = _calculateExpirationTime(identity.level);
    }


    function pauseContract(bool _paused) external onlyOwner {
        contractPaused = _paused;
        emit ContractPaused(_paused);
    }


    function getIdentity(address _user)
        external
        view
        returns (
            bytes32 identityHash,
            VerificationStatus status,
            IdentityLevel level,
            uint256 verificationTime,
            uint256 expirationTime,
            bool isActive
        )
    {
        Identity storage identity = identities[_user];
        return (
            identity.identityHash,
            identity.status,
            identity.level,
            identity.verificationTime,
            identity.expirationTime,
            identity.isActive
        );
    }

    function getVerifier(address _verifier)
        external
        view
        returns (
            bool isAuthorized,
            uint256 reputation,
            uint256 totalVerifications
        )
    {
        Verifier storage verifier = verifiers[_verifier];
        return (
            verifier.isAuthorized,
            verifier.reputation,
            verifier.totalVerifications
        );
    }

    function getUserStake(address _user) external view returns (uint256) {
        return userStakes[_user];
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getVerifiedUsersCount() external view returns (uint256) {
        return verifiedUsers.length;
    }

    function getVerifiersCount() external view returns (uint256) {
        return verifierList.length;
    }

    function isIdentityValid(address _user) external view returns (bool) {
        Identity storage identity = identities[_user];
        return identity.status == VerificationStatus.Verified &&
               identity.isActive &&
               block.timestamp <= identity.expirationTime;
    }


    function _verifySignature(bytes32 _hash, bytes memory _signature)
        internal
        view
        returns (bool)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(_hash, msg.sender));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(_signature);
        return signer == msg.sender;
    }

    function _calculateExpirationTime(IdentityLevel _level)
        internal
        view
        returns (uint256)
    {
        if (_level == IdentityLevel.Basic) {
            return block.timestamp + 180 days;
        } else if (_level == IdentityLevel.Standard) {
            return block.timestamp + 365 days;
        } else {
            return block.timestamp + 730 days;
        }
    }

    function _updateVerifierReputation(address _verifier, bool _successful) internal {
        if (_successful) {
            verifiers[_verifier].reputation += 1;
        } else if (verifiers[_verifier].reputation > 0) {
            verifiers[_verifier].reputation -= 1;
        }
    }

    function _removeFromVerifierList(address _verifier) internal {
        for (uint256 i = 0; i < verifierList.length; i++) {
            if (verifierList[i] == _verifier) {
                verifierList[i] = verifierList[verifierList.length - 1];
                verifierList.pop();
                break;
            }
        }
    }


    function emergencyWithdraw() external onlyOwner {
        require(contractPaused, "Contract must be paused");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }
}
