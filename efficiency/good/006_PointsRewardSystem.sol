
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PointsRewardSystem is Ownable, ReentrancyGuard, Pausable {

    mapping(address => uint256) private _balances;


    mapping(address => uint256) private _recordCount;


    mapping(address => mapping(uint256 => PointRecord)) private _pointRecords;


    mapping(address => bool) private _admins;


    uint256 private _exchangeRate;


    uint256 private _totalSupply;


    struct PointRecord {
        uint256 amount;
        uint8 actionType;
        uint256 timestamp;
        string description;
    }


    event PointsEarned(address indexed user, uint256 amount, string description);
    event PointsSpent(address indexed user, uint256 amount, string description);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);


    modifier onlyAdmin() {
        require(_admins[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    constructor(uint256 initialExchangeRate) {
        _exchangeRate = initialExchangeRate;
        _admins[msg.sender] = true;
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }


    function exchangeRate() external view returns (uint256) {
        return _exchangeRate;
    }


    function getRecordCount(address account) external view returns (uint256) {
        return _recordCount[account];
    }


    function getPointRecord(address account, uint256 index)
        external
        view
        returns (uint256 amount, uint8 actionType, uint256 timestamp, string memory description)
    {
        require(index < _recordCount[account], "Record not found");
        PointRecord storage record = _pointRecords[account][index];
        return (record.amount, record.actionType, record.timestamp, record.description);
    }


    function awardPoints(
        address user,
        uint256 amount,
        string calldata description
    )
        external
        onlyAdmin
        validAddress(user)
        whenNotPaused
    {
        require(amount > 0, "Amount must be positive");


        uint256 currentBalance = _balances[user];
        uint256 newBalance = currentBalance + amount;


        _balances[user] = newBalance;
        _totalSupply += amount;


        _addPointRecord(user, amount, 0, description);

        emit PointsEarned(user, amount, description);
    }


    function spendPoints(uint256 amount, string calldata description)
        external
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Amount must be positive");


        uint256 currentBalance = _balances[msg.sender];
        require(currentBalance >= amount, "Insufficient balance");


        uint256 newBalance = currentBalance - amount;
        _balances[msg.sender] = newBalance;
        _totalSupply -= amount;


        _addPointRecord(msg.sender, amount, 1, description);

        emit PointsSpent(msg.sender, amount, description);
    }


    function transferPoints(address to, uint256 amount)
        external
        validAddress(to)
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Amount must be positive");
        require(to != msg.sender, "Cannot transfer to self");


        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount, "Insufficient balance");


        uint256 receiverBalance = _balances[to];


        _balances[msg.sender] = senderBalance - amount;
        _balances[to] = receiverBalance + amount;


        _addPointRecord(msg.sender, amount, 2, "Transfer out");
        _addPointRecord(to, amount, 2, "Transfer in");

        emit PointsTransferred(msg.sender, to, amount);
    }


    function buyPoints() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must send ETH");

        uint256 pointsToMint = msg.value * _exchangeRate;


        uint256 currentBalance = _balances[msg.sender];


        _balances[msg.sender] = currentBalance + pointsToMint;
        _totalSupply += pointsToMint;


        _addPointRecord(msg.sender, pointsToMint, 0, "Purchased with ETH");

        emit PointsEarned(msg.sender, pointsToMint, "Purchased with ETH");
    }


    function batchBalanceOf(address[] calldata accounts)
        external
        view
        returns (uint256[] memory balances)
    {
        uint256 length = accounts.length;
        balances = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            balances[i] = _balances[accounts[i]];
            unchecked { ++i; }
        }
    }


    function addAdmin(address admin) external onlyOwner validAddress(admin) {
        _admins[admin] = true;
        emit AdminAdded(admin);
    }


    function removeAdmin(address admin) external onlyOwner validAddress(admin) {
        _admins[admin] = false;
        emit AdminRemoved(admin);
    }


    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }


    function setExchangeRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        uint256 oldRate = _exchangeRate;
        _exchangeRate = newRate;
        emit ExchangeRateUpdated(oldRate, newRate);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(owner()).transfer(amount);
    }


    function _addPointRecord(
        address user,
        uint256 amount,
        uint8 actionType,
        string memory description
    ) private {
        uint256 recordIndex = _recordCount[user];

        _pointRecords[user][recordIndex] = PointRecord({
            amount: amount,
            actionType: actionType,
            timestamp: block.timestamp,
            description: description
        });


        unchecked {
            _recordCount[user] = recordIndex + 1;
        }
    }


    function emergencyBurnPoints(address user, uint256 amount)
        external
        onlyOwner
        validAddress(user)
    {
        uint256 currentBalance = _balances[user];
        require(currentBalance >= amount, "Insufficient balance to burn");

        _balances[user] = currentBalance - amount;
        _totalSupply -= amount;

        _addPointRecord(user, amount, 1, "Emergency burn");
        emit PointsSpent(user, amount, "Emergency burn");
    }
}
