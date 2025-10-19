
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PointsRewardSystem is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;


    uint256 public constant MAX_POINTS_PER_ACTION = 10000;
    uint256 public constant MIN_REDEEM_AMOUNT = 100;
    uint256 public constant POINTS_DECIMALS = 18;
    uint256 public constant MAX_DAILY_EARN_LIMIT = 50000 * 10**POINTS_DECIMALS;


    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _dailyEarned;
    mapping(address => uint256) private _lastEarnDate;
    mapping(address => bool) private _authorizedOperators;
    mapping(uint256 => RewardTier) private _rewardTiers;

    uint256 private _totalSupply;
    uint256 private _nextTierId;
    string public name;
    string public symbol;


    struct RewardTier {
        uint256 id;
        string name;
        uint256 requiredPoints;
        uint256 multiplier;
        bool active;
    }


    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsRedeemed(address indexed user, uint256 amount, string item);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event RewardTierCreated(uint256 indexed tierId, string name, uint256 requiredPoints);
    event RewardTierUpdated(uint256 indexed tierId, bool active);
    event OperatorAuthorized(address indexed operator, bool authorized);


    modifier onlyAuthorized() {
        require(_authorizedOperators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be positive");
        _;
    }

    modifier checkDailyLimit(address account, uint256 amount) {
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
        _authorizedOperators[msg.sender] = true;
        _createDefaultTiers();
    }


    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function decimals() public pure returns (uint8) {
        return uint8(POINTS_DECIMALS);
    }

    function dailyEarned(address account) public view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        if (_lastEarnDate[account] != today) {
            return 0;
        }
        return _dailyEarned[account];
    }

    function getUserTier(address account) public view returns (RewardTier memory) {
        uint256 userPoints = _balances[account];
        uint256 highestTier = 0;

        for (uint256 i = 1; i < _nextTierId; i++) {
            if (_rewardTiers[i].active && userPoints >= _rewardTiers[i].requiredPoints) {
                if (_rewardTiers[i].requiredPoints > _rewardTiers[highestTier].requiredPoints) {
                    highestTier = i;
                }
            }
        }

        return _rewardTiers[highestTier];
    }

    function getRewardTier(uint256 tierId) public view returns (RewardTier memory) {
        return _rewardTiers[tierId];
    }

    function isAuthorizedOperator(address operator) public view returns (bool) {
        return _authorizedOperators[operator];
    }


    function earnPoints(
        address account,
        uint256 amount,
        string memory reason
    ) external
        onlyAuthorized
        validAddress(account)
        validAmount(amount)
        checkDailyLimit(account, amount)
        whenNotPaused
    {
        require(amount <= MAX_POINTS_PER_ACTION, "Amount exceeds maximum per action");


        RewardTier memory userTier = getUserTier(account);
        uint256 bonusAmount = amount.mul(userTier.multiplier).div(10000);
        uint256 totalAmount = amount.add(bonusAmount);

        _mint(account, totalAmount);


        uint256 today = block.timestamp / 1 days;
        if (_lastEarnDate[account] != today) {
            _dailyEarned[account] = 0;
            _lastEarnDate[account] = today;
        }
        _dailyEarned[account] = _dailyEarned[account].add(totalAmount);

        emit PointsEarned(account, totalAmount, reason);
    }

    function redeemPoints(
        uint256 amount,
        string memory item
    ) external
        validAmount(amount)
        whenNotPaused
        nonReentrant
    {
        require(amount >= MIN_REDEEM_AMOUNT, "Amount below minimum redemption");
        require(_balances[msg.sender] >= amount, "Insufficient points balance");

        _burn(msg.sender, amount);
        emit PointsRedeemed(msg.sender, amount, item);
    }

    function transfer(
        address to,
        uint256 amount
    ) external
        validAddress(to)
        validAmount(amount)
        whenNotPaused
        returns (bool)
    {
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _transfer(msg.sender, to, amount);
        return true;
    }

    function batchEarnPoints(
        address[] memory accounts,
        uint256[] memory amounts,
        string memory reason
    ) external onlyAuthorized whenNotPaused {
        require(accounts.length == amounts.length, "Arrays length mismatch");
        require(accounts.length <= 100, "Too many accounts");

        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && amounts[i] > 0 && amounts[i] <= MAX_POINTS_PER_ACTION) {
                uint256 today = block.timestamp / 1 days;
                if (_lastEarnDate[accounts[i]] != today) {
                    _dailyEarned[accounts[i]] = 0;
                    _lastEarnDate[accounts[i]] = today;
                }

                if (_dailyEarned[accounts[i]].add(amounts[i]) <= MAX_DAILY_EARN_LIMIT) {
                    RewardTier memory userTier = getUserTier(accounts[i]);
                    uint256 bonusAmount = amounts[i].mul(userTier.multiplier).div(10000);
                    uint256 totalAmount = amounts[i].add(bonusAmount);

                    _mint(accounts[i], totalAmount);
                    _dailyEarned[accounts[i]] = _dailyEarned[accounts[i]].add(totalAmount);

                    emit PointsEarned(accounts[i], totalAmount, reason);
                }
            }
        }
    }


    function setAuthorizedOperator(address operator, bool authorized) external onlyOwner validAddress(operator) {
        _authorizedOperators[operator] = authorized;
        emit OperatorAuthorized(operator, authorized);
    }

    function createRewardTier(
        string memory tierName,
        uint256 requiredPoints,
        uint256 multiplier
    ) external onlyOwner returns (uint256) {
        require(bytes(tierName).length > 0, "Invalid tier name");
        require(multiplier >= 10000, "Multiplier must be at least 100%");

        uint256 tierId = _nextTierId++;
        _rewardTiers[tierId] = RewardTier({
            id: tierId,
            name: tierName,
            requiredPoints: requiredPoints,
            multiplier: multiplier,
            active: true
        });

        emit RewardTierCreated(tierId, tierName, requiredPoints);
        return tierId;
    }

    function updateRewardTier(uint256 tierId, bool active) external onlyOwner {
        require(_rewardTiers[tierId].id == tierId, "Tier does not exist");
        _rewardTiers[tierId].active = active;
        emit RewardTierUpdated(tierId, active);
    }

    function emergencyWithdraw(address account, uint256 amount) external onlyOwner validAddress(account) {
        require(_balances[account] >= amount, "Insufficient balance");
        _burn(account, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function _mint(address account, uint256 amount) internal {
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
    }

    function _burn(address account, uint256 amount) internal {
        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount);
        emit PointsTransferred(from, to, amount);
    }

    function _createDefaultTiers() internal {

        _rewardTiers[0] = RewardTier({
            id: 0,
            name: "Bronze",
            requiredPoints: 0,
            multiplier: 10000,
            active: true
        });

        _nextTierId = 1;
    }
}
