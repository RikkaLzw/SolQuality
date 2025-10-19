
pragma solidity ^0.8.0;


contract PointsRewardSystem {

    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public blacklisted;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed recipient, uint256 indexed amount, string reason);
    event PointsBurned(address indexed account, uint256 indexed amount, string reason);
    event MinterAuthorized(address indexed minter, address indexed authorizer);
    event MinterRevoked(address indexed minter, address indexed revoker);
    event AccountBlacklisted(address indexed account, address indexed operator);
    event AccountUnblacklisted(address indexed account, address indexed operator);
    event ContractPaused(address indexed operator);
    event ContractUnpaused(address indexed operator);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    error InsufficientBalance(address account, uint256 requested, uint256 available);
    error InsufficientAllowance(address owner, address spender, uint256 requested, uint256 available);
    error UnauthorizedMinter(address caller);
    error AccountBlacklisted(address account);
    error ContractPaused();
    error ZeroAddress();
    error ZeroAmount();
    error Unauthorized(address caller);
    error InvalidInput(string reason);


    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender] && msg.sender != owner) {
            revert UnauthorizedMinter(msg.sender);
        }
        _;
    }

    modifier notPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _;
    }

    modifier notBlacklisted(address account) {
        if (blacklisted[account]) {
            revert AccountBlacklisted(account);
        }
        _;
    }

    modifier validAddress(address account) {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");

        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        authorizedMinters[msg.sender] = true;

        emit MinterAuthorized(msg.sender, msg.sender);
        emit OwnershipTransferred(address(0), msg.sender);
    }


    function awardPoints(
        address recipient,
        uint256 amount,
        string calldata reason
    )
        external
        onlyAuthorizedMinter
        notPaused
        validAddress(recipient)
        validAmount(amount)
        notBlacklisted(recipient)
    {
        require(bytes(reason).length > 0, "Reason cannot be empty");

        balances[recipient] += amount;
        totalSupply += amount;

        emit Transfer(address(0), recipient, amount);
        emit PointsAwarded(recipient, amount, reason);
    }


    function burnPoints(
        address account,
        uint256 amount,
        string calldata reason
    )
        external
        onlyAuthorizedMinter
        notPaused
        validAddress(account)
        validAmount(amount)
    {
        require(bytes(reason).length > 0, "Reason cannot be empty");

        uint256 accountBalance = balances[account];
        if (accountBalance < amount) {
            revert InsufficientBalance(account, amount, accountBalance);
        }

        balances[account] = accountBalance - amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
        emit PointsBurned(account, amount, reason);
    }


    function transfer(address to, uint256 amount)
        external
        notPaused
        validAddress(to)
        validAmount(amount)
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount)
        external
        notPaused
        validAddress(from)
        validAddress(to)
        validAmount(amount)
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(from, msg.sender, amount, currentAllowance);
        }

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);

        return true;
    }


    function approve(address spender, uint256 amount)
        external
        validAddress(spender)
        notBlacklisted(msg.sender)
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }


    function _transfer(address from, address to, uint256 amount) internal {
        uint256 fromBalance = balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(from, amount, fromBalance);
        }

        balances[from] = fromBalance - amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }


    function _approve(address owner, address spender, uint256 amount) internal {
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function authorizeMinter(address minter)
        external
        onlyOwner
        validAddress(minter)
    {
        require(!authorizedMinters[minter], "Address is already an authorized minter");

        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter, msg.sender);
    }


    function revokeMinter(address minter)
        external
        onlyOwner
        validAddress(minter)
    {
        require(minter != owner, "Cannot revoke owner's minter status");
        require(authorizedMinters[minter], "Address is not an authorized minter");

        authorizedMinters[minter] = false;
        emit MinterRevoked(minter, msg.sender);
    }


    function blacklistAccount(address account)
        external
        onlyOwner
        validAddress(account)
    {
        require(account != owner, "Cannot blacklist owner");
        require(!blacklisted[account], "Account is already blacklisted");

        blacklisted[account] = true;
        emit AccountBlacklisted(account, msg.sender);
    }


    function unblacklistAccount(address account)
        external
        onlyOwner
        validAddress(account)
    {
        require(blacklisted[account], "Account is not blacklisted");

        blacklisted[account] = false;
        emit AccountUnblacklisted(account, msg.sender);
    }


    function pause() external onlyOwner {
        require(!paused, "Contract is already paused");

        paused = true;
        emit ContractPaused(msg.sender);
    }


    function unpause() external onlyOwner {
        require(paused, "Contract is not paused");

        paused = false;
        emit ContractUnpaused(msg.sender);
    }


    function transferOwnership(address newOwner)
        external
        onlyOwner
        validAddress(newOwner)
    {
        require(newOwner != owner, "New owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;
        authorizedMinters[newOwner] = true;

        emit MinterAuthorized(newOwner, previousOwner);
        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }


    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }


    function isAuthorizedMinter(address account) external view returns (bool) {
        return authorizedMinters[account];
    }


    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }
}
