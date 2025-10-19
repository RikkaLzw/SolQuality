
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PointsSystem is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;


    uint256 public constant MAX_POINTS_PER_ACTION = 1000;
    uint256 public constant MIN_POINTS_FOR_REDEMPTION = 10;
    uint256 public constant POINTS_DECIMALS = 18;
    uint256 public constant MAX_DAILY_EARN_LIMIT = 5000;


    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _dailyEarned;
    mapping(address => uint256) private _lastEarnDate;
    mapping(address => bool) private _authorized;
    mapping(uint256 => RedemptionItem) private _redemptionItems;

    uint256 private _totalSupply;
    uint256 private _nextItemId;
    string public name;
    string public symbol;


    struct RedemptionItem {
        string name;
        uint256 cost;
        bool active;
        uint256 stock;
    }


    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event AuthorizedAdded(address indexed account);
    event AuthorizedRemoved(address indexed account);
    event RedemptionItemAdded(uint256 indexed itemId, string name, uint256 cost);
    event RedemptionItemUpdated(uint256 indexed itemId, uint256 newCost, bool active);
    event ItemRedeemed(address indexed user, uint256 indexed itemId, uint256 cost);


    modifier onlyAuthorized() {
        require(_authorized[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        _;
    }

    modifier itemExists(uint256 itemId) {
        require(itemId < _nextItemId, "Item does not exist");
        _;
    }

    modifier sufficientBalance(address account, uint256 amount) {
        require(_balances[account] >= amount, "Insufficient balance");
        _;
    }

    modifier withinDailyLimit(address account, uint256 amount) {
        uint256 today = block.timestamp / 1 days;
        if (_lastEarnDate[account] != today) {
            _dailyEarned[account] = 0;
            _lastEarnDate[account] = today;
        }
        require(_dailyEarned[account].add(amount) <= MAX_DAILY_EARN_LIMIT, "Daily earn limit exceeded");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        _authorized[msg.sender] = true;
    }


    function earnPoints(
        address user,
        uint256 amount,
        string memory reason
    )
        external
        onlyAuthorized
        whenNotPaused
        validAddress(user)
        validAmount(amount)
        withinDailyLimit(user, amount)
    {
        require(amount <= MAX_POINTS_PER_ACTION, "Amount exceeds maximum per action");

        _updateDailyEarned(user, amount);
        _balances[user] = _balances[user].add(amount);
        _totalSupply = _totalSupply.add(amount);

        emit PointsEarned(user, amount, reason);
    }

    function spendPoints(
        address user,
        uint256 amount,
        string memory reason
    )
        external
        onlyAuthorized
        whenNotPaused
        validAddress(user)
        validAmount(amount)
        sufficientBalance(user, amount)
    {
        require(amount >= MIN_POINTS_FOR_REDEMPTION, "Amount below minimum redemption");

        _balances[user] = _balances[user].sub(amount);
        _totalSupply = _totalSupply.sub(amount);

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
        sufficientBalance(msg.sender, amount)
        nonReentrant
    {
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit PointsTransferred(msg.sender, to, amount);
    }


    function addRedemptionItem(
        string memory itemName,
        uint256 cost,
        uint256 stock
    )
        external
        onlyOwner
        validAmount(cost)
    {
        require(bytes(itemName).length > 0, "Item name cannot be empty");

        _redemptionItems[_nextItemId] = RedemptionItem({
            name: itemName,
            cost: cost,
            active: true,
            stock: stock
        });

        emit RedemptionItemAdded(_nextItemId, itemName, cost);
        _nextItemId++;
    }

    function updateRedemptionItem(
        uint256 itemId,
        uint256 newCost,
        bool active,
        uint256 newStock
    )
        external
        onlyOwner
        itemExists(itemId)
    {
        RedemptionItem storage item = _redemptionItems[itemId];
        item.cost = newCost;
        item.active = active;
        item.stock = newStock;

        emit RedemptionItemUpdated(itemId, newCost, active);
    }

    function redeemItem(uint256 itemId)
        external
        whenNotPaused
        itemExists(itemId)
        nonReentrant
    {
        RedemptionItem storage item = _redemptionItems[itemId];
        require(item.active, "Item is not active");
        require(item.stock > 0, "Item out of stock");
        require(_balances[msg.sender] >= item.cost, "Insufficient points");

        _balances[msg.sender] = _balances[msg.sender].sub(item.cost);
        _totalSupply = _totalSupply.sub(item.cost);
        item.stock = item.stock.sub(1);

        emit ItemRedeemed(msg.sender, itemId, item.cost);
    }


    function addAuthorized(address account)
        external
        onlyOwner
        validAddress(account)
    {
        _authorized[account] = true;
        emit AuthorizedAdded(account);
    }

    function removeAuthorized(address account)
        external
        onlyOwner
        validAddress(account)
    {
        _authorized[account] = false;
        emit AuthorizedRemoved(account);
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function isAuthorized(address account) external view returns (bool) {
        return _authorized[account];
    }

    function getDailyEarned(address account) external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        if (_lastEarnDate[account] != today) {
            return 0;
        }
        return _dailyEarned[account];
    }

    function getRemainingDailyLimit(address account) external view returns (uint256) {
        uint256 earned = this.getDailyEarned(account);
        return MAX_DAILY_EARN_LIMIT.sub(earned);
    }

    function getRedemptionItem(uint256 itemId)
        external
        view
        itemExists(itemId)
        returns (string memory name, uint256 cost, bool active, uint256 stock)
    {
        RedemptionItem memory item = _redemptionItems[itemId];
        return (item.name, item.cost, item.active, item.stock);
    }

    function getTotalRedemptionItems() external view returns (uint256) {
        return _nextItemId;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }


    function _updateDailyEarned(address account, uint256 amount) private {
        uint256 today = block.timestamp / 1 days;
        if (_lastEarnDate[account] != today) {
            _dailyEarned[account] = 0;
            _lastEarnDate[account] = today;
        }
        _dailyEarned[account] = _dailyEarned[account].add(amount);
    }


    function batchEarnPoints(
        address[] calldata users,
        uint256[] calldata amounts,
        string memory reason
    )
        external
        onlyAuthorized
        whenNotPaused
    {
        require(users.length == amounts.length, "Arrays length mismatch");
        require(users.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] != address(0) && amounts[i] > 0 && amounts[i] <= MAX_POINTS_PER_ACTION) {
                uint256 today = block.timestamp / 1 days;
                if (_lastEarnDate[users[i]] != today) {
                    _dailyEarned[users[i]] = 0;
                    _lastEarnDate[users[i]] = today;
                }

                if (_dailyEarned[users[i]].add(amounts[i]) <= MAX_DAILY_EARN_LIMIT) {
                    _updateDailyEarned(users[i], amounts[i]);
                    _balances[users[i]] = _balances[users[i]].add(amounts[i]);
                    _totalSupply = _totalSupply.add(amounts[i]);
                    emit PointsEarned(users[i], amounts[i], reason);
                }
            }
        }
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}
