
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PointsSystem is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;


    uint256 public constant MAX_POINTS_PER_ACTION = 10000;
    uint256 public constant MIN_REDEEM_AMOUNT = 100;
    uint256 public constant DAILY_LIMIT = 50000;
    uint256 public constant REFERRAL_BONUS_RATE = 10;


    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _dailyEarned;
    mapping(address => uint256) private _lastEarnDate;
    mapping(address => address) private _referrers;
    mapping(address => uint256) private _totalEarned;
    mapping(address => uint256) private _totalRedeemed;
    mapping(bytes32 => bool) private _usedNonces;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;


    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsRedeemed(address indexed user, uint256 amount, string item);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event ReferralBonusAwarded(address indexed referrer, address indexed referee, uint256 bonus);
    event DailyLimitUpdated(address indexed user, uint256 newLimit);


    modifier validAddress(address account) {
        require(account != address(0), "PointsSystem: invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "PointsSystem: amount must be positive");
        _;
    }

    modifier nonceNotUsed(bytes32 nonce) {
        require(!_usedNonces[nonce], "PointsSystem: nonce already used");
        _;
    }

    modifier withinDailyLimit(address user, uint256 amount) {
        if (_isNewDay(user)) {
            _dailyEarned[user] = 0;
            _lastEarnDate[user] = block.timestamp;
        }
        require(
            _dailyEarned[user].add(amount) <= DAILY_LIMIT,
            "PointsSystem: exceeds daily limit"
        );
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }


    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function dailyEarned(address account) public view returns (uint256) {
        return _dailyEarned[account];
    }

    function totalEarned(address account) public view returns (uint256) {
        return _totalEarned[account];
    }

    function totalRedeemed(address account) public view returns (uint256) {
        return _totalRedeemed[account];
    }

    function getReferrer(address account) public view returns (address) {
        return _referrers[account];
    }


    function earnPoints(
        address user,
        uint256 amount,
        string calldata reason,
        bytes32 nonce
    )
        external
        onlyOwner
        whenNotPaused
        validAddress(user)
        validAmount(amount)
        nonceNotUsed(nonce)
        withinDailyLimit(user, amount)
    {
        require(amount <= MAX_POINTS_PER_ACTION, "PointsSystem: exceeds max points per action");

        _usedNonces[nonce] = true;
        _mint(user, amount, reason);
        _updateDailyEarned(user, amount);


        address referrer = _referrers[user];
        if (referrer != address(0)) {
            uint256 bonus = amount.mul(REFERRAL_BONUS_RATE).div(100);
            _mint(referrer, bonus, "Referral bonus");
            emit ReferralBonusAwarded(referrer, user, bonus);
        }
    }

    function redeemPoints(
        uint256 amount,
        string calldata item
    )
        external
        whenNotPaused
        validAmount(amount)
        nonReentrant
    {
        require(amount >= MIN_REDEEM_AMOUNT, "PointsSystem: below minimum redeem amount");
        require(_balances[msg.sender] >= amount, "PointsSystem: insufficient balance");

        _burn(msg.sender, amount);
        _totalRedeemed[msg.sender] = _totalRedeemed[msg.sender].add(amount);

        emit PointsRedeemed(msg.sender, amount, item);
    }

    function transfer(
        address to,
        uint256 amount
    )
        external
        whenNotPaused
        validAddress(to)
        validAmount(amount)
        nonReentrant
        returns (bool)
    {
        require(_balances[msg.sender] >= amount, "PointsSystem: insufficient balance");
        require(to != msg.sender, "PointsSystem: cannot transfer to self");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit PointsTransferred(msg.sender, to, amount);
        return true;
    }

    function setReferrer(address referrer)
        external
        validAddress(referrer)
    {
        require(_referrers[msg.sender] == address(0), "PointsSystem: referrer already set");
        require(referrer != msg.sender, "PointsSystem: cannot refer self");

        _referrers[msg.sender] = referrer;
    }


    function adminMint(
        address to,
        uint256 amount,
        string calldata reason
    )
        external
        onlyOwner
        validAddress(to)
        validAmount(amount)
    {
        _mint(to, amount, reason);
    }

    function adminBurn(
        address from,
        uint256 amount
    )
        external
        onlyOwner
        validAddress(from)
        validAmount(amount)
    {
        require(_balances[from] >= amount, "PointsSystem: insufficient balance");
        _burn(from, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function resetDailyLimit(address user)
        external
        onlyOwner
        validAddress(user)
    {
        _dailyEarned[user] = 0;
        _lastEarnDate[user] = block.timestamp;
        emit DailyLimitUpdated(user, 0);
    }


    function _mint(
        address account,
        uint256 amount,
        string memory reason
    ) internal {
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        _totalEarned[account] = _totalEarned[account].add(amount);

        emit PointsEarned(account, amount, reason);
    }

    function _burn(address account, uint256 amount) internal {
        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
    }

    function _updateDailyEarned(address user, uint256 amount) internal {
        if (_isNewDay(user)) {
            _dailyEarned[user] = amount;
            _lastEarnDate[user] = block.timestamp;
        } else {
            _dailyEarned[user] = _dailyEarned[user].add(amount);
        }
    }

    function _isNewDay(address user) internal view returns (bool) {
        return block.timestamp >= _lastEarnDate[user].add(1 days);
    }
}
