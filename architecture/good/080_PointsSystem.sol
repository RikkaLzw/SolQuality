
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PointsSystem is Ownable, ReentrancyGuard, Pausable {


    uint256 public constant MAX_POINTS_PER_ACTION = 1000;
    uint256 public constant MIN_TRANSFER_AMOUNT = 1;
    uint256 public constant MAX_TRANSFER_AMOUNT = 10000;
    uint256 public constant DAILY_EARN_LIMIT = 5000;


    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _dailyEarned;
    mapping(address => uint256) private _lastEarnDate;
    mapping(address => bool) private _authorizedEarners;

    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;


    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event AuthorizedEarnerAdded(address indexed earner);
    event AuthorizedEarnerRemoved(address indexed earner);


    modifier onlyAuthorizedEarner() {
        require(_authorizedEarners[msg.sender] || msg.sender == owner(), "Not authorized to award points");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier checkDailyLimit(address user, uint256 amount) {
        _updateDailyEarned(user);
        require(_dailyEarned[user] + amount <= DAILY_EARN_LIMIT, "Daily earning limit exceeded");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _authorizedEarners[msg.sender] = true;
    }


    function awardPoints(
        address user,
        uint256 amount,
        string memory reason
    )
        external
        onlyAuthorizedEarner
        whenNotPaused
        validAddress(user)
        validAmount(amount)
        checkDailyLimit(user, amount)
    {
        require(amount <= MAX_POINTS_PER_ACTION, "Amount exceeds maximum per action");

        _mint(user, amount);
        _dailyEarned[user] += amount;

        emit PointsEarned(user, amount, reason);
    }


    function spendPoints(
        address user,
        uint256 amount,
        string memory reason
    )
        external
        onlyAuthorizedEarner
        whenNotPaused
        validAddress(user)
        validAmount(amount)
    {
        require(_balances[user] >= amount, "Insufficient points balance");

        _burn(user, amount);

        emit PointsSpent(user, amount, reason);
    }


    function transferPoints(
        address to,
        uint256 amount
    )
        external
        whenNotPaused
        validAddress(to)
        validAmount(amount)
        nonReentrant
    {
        require(amount >= MIN_TRANSFER_AMOUNT && amount <= MAX_TRANSFER_AMOUNT, "Transfer amount out of range");
        require(_balances[msg.sender] >= amount, "Insufficient points balance");
        require(to != msg.sender, "Cannot transfer to self");

        _transfer(msg.sender, to, amount);

        emit PointsTransferred(msg.sender, to, amount);
    }


    function addAuthorizedEarner(address earner) external onlyOwner validAddress(earner) {
        _authorizedEarners[earner] = true;
        emit AuthorizedEarnerAdded(earner);
    }


    function removeAuthorizedEarner(address earner) external onlyOwner validAddress(earner) {
        _authorizedEarners[earner] = false;
        emit AuthorizedEarnerRemoved(earner);
    }


    function isAuthorizedEarner(address earner) external view returns (bool) {
        return _authorizedEarners[earner];
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }


    function getDailyEarned(address user) external view returns (uint256) {
        if (_isNewDay(user)) {
            return 0;
        }
        return _dailyEarned[user];
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function _mint(address account, uint256 amount) internal {
        _totalSupply += amount;
        _balances[account] += amount;
    }

    function _burn(address account, uint256 amount) internal {
        _balances[account] -= amount;
        _totalSupply -= amount;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        _balances[from] -= amount;
        _balances[to] += amount;
    }

    function _updateDailyEarned(address user) internal {
        if (_isNewDay(user)) {
            _dailyEarned[user] = 0;
            _lastEarnDate[user] = _getCurrentDay();
        }
    }

    function _isNewDay(address user) internal view returns (bool) {
        return _getCurrentDay() > _lastEarnDate[user];
    }

    function _getCurrentDay() internal view returns (uint256) {
        return block.timestamp / 86400;
    }
}
