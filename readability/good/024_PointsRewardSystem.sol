
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
        uint256 transactionTimestamp;
        string transactionDescription;
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
        require(
            msg.sender == contractOwner,
            "Only contract owner can perform this action"
        );
        _;
    }


    modifier onlyAuthorizedMerchant() {
        require(
            authorizedMerchants[msg.sender],
            "Only authorized merchants can perform this action"
        );
        _;
    }


    modifier hasSufficientPoints(address userAddress, uint256 requiredPoints) {
        require(
            userPointsBalance[userAddress] >= requiredPoints,
            "Insufficient points balance"
        );
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
    {
        require(
            merchantAddress != address(0),
            "Invalid merchant address"
        );
        require(
            !authorizedMerchants[merchantAddress],
            "Merchant already authorized"
        );

        authorizedMerchants[merchantAddress] = true;

        emit MerchantAuthorized(merchantAddress, block.timestamp);
    }


    function revokeMerchantAuthorization(address merchantAddress)
        external
        onlyContractOwner
    {
        require(
            authorizedMerchants[merchantAddress],
            "Merchant not authorized"
        );

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
    {
        require(
            userAddress != address(0),
            "Invalid user address"
        );
        require(
            pointsAmount > 0,
            "Points amount must be greater than zero"
        );


        userPointsBalance[userAddress] += pointsAmount;


        totalPointsSupply += pointsAmount;


        _recordTransaction(
            address(0),
            userAddress,
            pointsAmount,
            "earn",
            description
        );

        emit PointsEarned(
            userAddress,
            pointsAmount,
            description,
            block.timestamp
        );
    }


    function spendUserPoints(
        uint256 pointsAmount,
        string memory description
    )
        external
        hasSufficientPoints(msg.sender, pointsAmount)
    {
        require(
            pointsAmount > 0,
            "Points amount must be greater than zero"
        );


        userPointsBalance[msg.sender] -= pointsAmount;


        totalPointsSupply -= pointsAmount;


        _recordTransaction(
            msg.sender,
            address(0),
            pointsAmount,
            "spend",
            description
        );

        emit PointsSpent(
            msg.sender,
            msg.sender,
            pointsAmount,
            description,
            block.timestamp
        );
    }


    function transferPointsBetweenUsers(
        address recipientAddress,
        uint256 pointsAmount
    )
        external
        hasSufficientPoints(msg.sender, pointsAmount)
    {
        require(
            recipientAddress != address(0),
            "Invalid recipient address"
        );
        require(
            recipientAddress != msg.sender,
            "Cannot transfer to yourself"
        );
        require(
            pointsAmount > 0,
            "Points amount must be greater than zero"
        );


        userPointsBalance[msg.sender] -= pointsAmount;


        userPointsBalance[recipientAddress] += pointsAmount;


        _recordTransaction(
            msg.sender,
            recipientAddress,
            pointsAmount,
            "transfer",
            "Points transfer sent"
        );


        _recordTransaction(
            msg.sender,
            recipientAddress,
            pointsAmount,
            "transfer",
            "Points transfer received"
        );

        emit PointsTransferred(
            msg.sender,
            recipientAddress,
            pointsAmount,
            block.timestamp
        );
    }


    function getUserPointsBalance(address userAddress)
        external
        view
        returns (uint256)
    {
        return userPointsBalance[userAddress];
    }


    function getUserTransactionCount(address userAddress)
        external
        view
        returns (uint256)
    {
        return userTransactionHistory[userAddress].length;
    }


    function getUserTransactionDetails(
        address userAddress,
        uint256 transactionIndex
    )
        external
        view
        returns (
            uint256 transactionId,
            address fromAddress,
            address toAddress,
            uint256 pointsAmount,
            string memory transactionType,
            uint256 transactionTimestamp,
            string memory transactionDescription
        )
    {
        require(
            transactionIndex < userTransactionHistory[userAddress].length,
            "Transaction index out of bounds"
        );

        PointsTransaction memory transaction = userTransactionHistory[userAddress][transactionIndex];

        return (
            transaction.transactionId,
            transaction.fromAddress,
            transaction.toAddress,
            transaction.pointsAmount,
            transaction.transactionType,
            transaction.transactionTimestamp,
            transaction.transactionDescription
        );
    }


    function isAuthorizedMerchant(address merchantAddress)
        external
        view
        returns (bool)
    {
        return authorizedMerchants[merchantAddress];
    }


    function _recordTransaction(
        address fromAddress,
        address toAddress,
        uint256 pointsAmount,
        string memory transactionType,
        string memory description
    )
        private
    {
        PointsTransaction memory newTransaction = PointsTransaction({
            transactionId: transactionIdCounter,
            fromAddress: fromAddress,
            toAddress: toAddress,
            pointsAmount: pointsAmount,
            transactionType: transactionType,
            transactionTimestamp: block.timestamp,
            transactionDescription: description
        });


        if (fromAddress != address(0)) {
            userTransactionHistory[fromAddress].push(newTransaction);
        }


        if (toAddress != address(0) && toAddress != fromAddress) {
            userTransactionHistory[toAddress].push(newTransaction);
        }

        transactionIdCounter++;
    }


    function emergencyGetUserBalance(address userAddress)
        external
        view
        onlyContractOwner
        returns (uint256)
    {
        return userPointsBalance[userAddress];
    }


    function transferContractOwnership(address newOwnerAddress)
        external
        onlyContractOwner
    {
        require(
            newOwnerAddress != address(0),
            "Invalid new owner address"
        );
        require(
            newOwnerAddress != contractOwner,
            "New owner must be different from current owner"
        );

        contractOwner = newOwnerAddress;
    }
}
