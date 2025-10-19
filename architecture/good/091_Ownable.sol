
pragma solidity ^0.8.0;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() public onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract StandardERC20Token is IERC20, Ownable {
    using SafeMath for uint256;


    string public constant NAME = "Standard Token";
    string public constant SYMBOL = "STD";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**DECIMALS;
    uint256 public constant MAX_SUPPLY = 10000000 * 10**DECIMALS;


    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _blacklisted;

    uint256 private _totalSupply;
    bool private _paused;


    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Pause();
    event Unpause();
    event BlacklistUpdated(address indexed account, bool isBlacklisted);


    modifier whenNotPaused() {
        require(!_paused, "Token: contract is paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Token: contract is not paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!_blacklisted[account], "Token: account is blacklisted");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Token: invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Token: amount must be greater than zero");
        _;
    }

    constructor() {
        _totalSupply = INITIAL_SUPPLY;
        _balances[msg.sender] = INITIAL_SUPPLY;
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }


    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        validAddress(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        notBlacklisted(msg.sender)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance.sub(amount));

        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        validAddress(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        validAddress(spender)
        returns (bool)
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance.sub(subtractedValue));
        return true;
    }


    function mint(address to, uint256 amount)
        public
        onlyOwner
        whenNotPaused
        notBlacklisted(to)
        validAddress(to)
        validAmount(amount)
    {
        require(_totalSupply.add(amount) <= MAX_SUPPLY, "Token: minting would exceed max supply");

        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    function burn(uint256 amount)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        validAmount(amount)
    {
        require(_balances[msg.sender] >= amount, "Token: burn amount exceeds balance");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpause();
    }

    function updateBlacklist(address account, bool isBlacklisted)
        public
        onlyOwner
        validAddress(account)
    {
        _blacklisted[account] = isBlacklisted;
        emit BlacklistUpdated(account, isBlacklisted);
    }


    function paused() public view returns (bool) {
        return _paused;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }


    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");

        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
