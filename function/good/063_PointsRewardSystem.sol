
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    mapping(address => uint256) private userPoints;
    mapping(address => bool) private authorizedOperators;

    address private owner;
    uint256 private totalPointsIssued;

    event PointsAwarded(address indexed user, uint256 amount, string reason);
    event PointsRedeemed(address indexed user, uint256 amount, string item);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedOperators[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOperators[msg.sender] = true;
    }

    function awardPoints(address user, uint256 amount) external onlyAuthorized {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be positive");

        userPoints[user] += amount;
        totalPointsIssued += amount;

        emit PointsAwarded(user, amount, "Points awarded");
    }

    function awardPointsWithReason(address user, uint256 amount, string calldata reason) external onlyAuthorized {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be positive");

        userPoints[user] += amount;
        totalPointsIssued += amount;

        emit PointsAwarded(user, amount, reason);
    }

    function redeemPoints(uint256 amount, string calldata item) external {
        require(amount > 0, "Amount must be positive");
        require(userPoints[msg.sender] >= amount, "Insufficient points");

        userPoints[msg.sender] -= amount;

        emit PointsRedeemed(msg.sender, amount, item);
    }

    function transferPoints(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be positive");
        require(userPoints[msg.sender] >= amount, "Insufficient points");

        userPoints[msg.sender] -= amount;
        userPoints[to] += amount;
    }

    function addOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator address");

        authorizedOperators[operator] = true;

        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator address");
        require(operator != owner, "Cannot remove owner");

        authorizedOperators[operator] = false;

        emit OperatorRemoved(operator);
    }

    function getBalance(address user) external view returns (uint256) {
        return userPoints[user];
    }

    function getMyBalance() external view returns (uint256) {
        return userPoints[msg.sender];
    }

    function getTotalPointsIssued() external view returns (uint256) {
        return totalPointsIssued;
    }

    function isAuthorizedOperator(address operator) external view returns (bool) {
        return authorizedOperators[operator];
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}
