
pragma solidity ^0.8.0;


contract PointsRewardSystem {


    address public contractOwner;


    uint256 public totalPointsSupply;


    mapping(address => uint256) public userPointsBalance;


    mapping(address => PointsTransaction[]) public userTransactionHistory;


    mapping(address => bool) public authorizedMerchants;


    struct PointsTransaction {
        uint256 transactionId;
        address fromAddress;
        address toAddress;
        uint256 pointsAmount;
        string transactionType;
        uint256 timestamp;
        string description;
    }


    uint256 private transactionIdCounter;


    event PointsEarned(
        address indexed userAddress,
        uint256 pointsAmount,
        string description,
        uint256 timestamp
    );

    event PointsSpent(
        address indexed userAddress,
        address indexed merchantAddress,
        uint256 pointsAmount,
        string description,
        uint256 timestamp
    );

    event PointsTransferred(
        address indexed fromAddress,
        address indexed toAddress,
        uint256 pointsAmount,
        uint256 timestamp
    );

    event MerchantAuthorized(
        address indexed merchantAddress,
        uint256 timestamp
    );

    event MerchantRevoked(
        address indexed merchantAddress,
        uint256 timestamp
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }


    modifier onlyAuthorizedMerchant() {
        require(authorizedMerchants[msg.sender], "Only authorized merchants can perform this action");
        _;
    }


    modifier hasSufficientPoints(address userAddress, uint256 requiredPoints) {
        require(userPointsBalance[userAddress] >= requiredPoints, "Insufficient points balance");
        _;
    }


    modifier validAddress(address targetAddress) {
        require(targetAddress != address(0), "Invalid address provided");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        totalPointsSupply = 0;
        transactionIdCounter = 1;
    }


    function authorizeMerchant(address merchantAddress)
        external
        onlyContractOwner
        validAddress(merchantAddress)
    {
        require(!authorizedMerchants[merchantAddress], "Merchant already authorized");

        authorizedMerchants[merchantAddress] = true;

        emit MerchantAuthorized(merchantAddress, block.timestamp);
    }


    function revokeMerchantAuthorization(address merchantAddress)
        external
        onlyContractOwner
        validAddress(merchantAddress)
    {
        require(authorizedMerchants[merchantAddress], "Merchant not authorized");

        authorizedMerchants[merchantAddress] = false;

        emit MerchantRevoked(merchantAddress, block.timestamp);
    }


    function awardPointsToUser(
        address userAddress,
        uint256 pointsAmount,
        string memory description
    )
        external
        onlyAuthorizedMerchant
        validAddress(userAddress)
    {
        require(pointsAmount > 0, "Points amount must be greater than zero");


        userPointsBalance[userAddress] += pointsAmount;


        totalPointsSupply += pointsAmount;


        PointsTransaction memory newTransaction = PointsTransaction({
            transactionId: transactionIdCounter,
            fromAddress: msg.sender,
            toAddress: userAddress,
            pointsAmount: pointsAmount,
            transactionType: "earn",
            timestamp: block.timestamp,
            description: description
        });

        userTransactionHistory[userAddress].push(newTransaction);
        transactionIdCounter++;

        emit PointsEarned(userAddress, pointsAmount, description, block.timestamp);
    }


    function spendUserPoints(
        address userAddress,
        uint256 pointsAmount,
        string memory description
    )
        external
        onlyAuthorizedMerchant
        validAddress(userAddress)
        hasSufficientPoints(userAddress, pointsAmount)
    {
        require(pointsAmount > 0, "Points amount must be greater than zero");


        userPointsBalance[userAddress] -= pointsAmount;


        totalPointsSupply -= pointsAmount;


        PointsTransaction memory newTransaction = PointsTransaction({
            transactionId: transactionIdCounter,
            fromAddress: userAddress,
            toAddress: msg.sender,
            pointsAmount: pointsAmount,
            transactionType: "spend",
            timestamp: block.timestamp,
            description: description
        });

        userTransactionHistory[userAddress].push(newTransaction);
        transactionIdCounter++;

        emit PointsSpent(userAddress, msg.sender, pointsAmount, description, block.timestamp);
    }


    function transferPointsBetweenUsers(
        address recipientAddress,
        uint256 pointsAmount
    )
        external
        validAddress(recipientAddress)
        hasSufficientPoints(msg.sender, pointsAmount)
    {
        require(pointsAmount > 0, "Points amount must be greater than zero");
        require(msg.sender != recipientAddress, "Cannot transfer points to yourself");


        userPointsBalance[msg.sender] -= pointsAmount;


        userPointsBalance[recipientAddress] += pointsAmount;


        PointsTransaction memory senderTransaction = PointsTransaction({
            transactionId: transactionIdCounter,
            fromAddress: msg.sender,
            toAddress: recipientAddress,
            pointsAmount: pointsAmount,
            transactionType: "transfer",
            timestamp: block.timestamp,
            description: "Points transfer to user"
        });

        userTransactionHistory[msg.sender].push(senderTransaction);


        PointsTransaction memory recipientTransaction = PointsTransaction({
            transactionId: transactionIdCounter,
            fromAddress: msg.sender,
            toAddress: recipientAddress,
            pointsAmount: pointsAmount,
            transactionType: "transfer",
            timestamp: block.timestamp,
            description: "Points received from user"
        });

        userTransactionHistory[recipientAddress].push(recipientTransaction);
        transactionIdCounter++;

        emit PointsTransferred(msg.sender, recipientAddress, pointsAmount, block.timestamp);
    }


    function getUserPointsBalance(address userAddress)
        external
        view
        validAddress(userAddress)
        returns (uint256)
    {
        return userPointsBalance[userAddress];
    }


    function getUserTransactionCount(address userAddress)
        external
        view
        validAddress(userAddress)
        returns (uint256)
    {
        return userTransactionHistory[userAddress].length;
    }


    function getUserTransactionByIndex(
        address userAddress,
        uint256 transactionIndex
    )
        external
        view
        validAddress(userAddress)
        returns (
            uint256 transactionId,
            address fromAddress,
            address toAddress,
            uint256 pointsAmount,
            string memory transactionType,
            uint256 timestamp,
            string memory description
        )
    {
        require(transactionIndex < userTransactionHistory[userAddress].length, "Transaction index out of bounds");

        PointsTransaction memory transaction = userTransactionHistory[userAddress][transactionIndex];

        return (
            transaction.transactionId,
            transaction.fromAddress,
            transaction.toAddress,
            transaction.pointsAmount,
            transaction.transactionType,
            transaction.timestamp,
            transaction.description
        );
    }


    function isMerchantAuthorized(address merchantAddress)
        external
        view
        validAddress(merchantAddress)
        returns (bool)
    {
        return authorizedMerchants[merchantAddress];
    }


    function getTotalPointsSupply()
        external
        view
        returns (uint256)
    {
        return totalPointsSupply;
    }


    function transferContractOwnership(address newOwnerAddress)
        external
        onlyContractOwner
        validAddress(newOwnerAddress)
    {
        require(newOwnerAddress != contractOwner, "New owner must be different from current owner");

        contractOwner = newOwnerAddress;
    }
}
