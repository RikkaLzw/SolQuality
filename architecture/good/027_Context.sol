
pragma solidity ^0.8.0;

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract StandardERC20Token is IERC20, Context, Ownable {
    using SafeMath for uint256;


    uint256 private constant MAX_SUPPLY = 1000000000 * 10**18;
    uint8 private constant DECIMALS = 18;


    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _blacklisted;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    bool private _paused;


    event Paused();
    event Unpaused();
    event Blacklisted(address indexed account);
    event RemovedFromBlacklist(address indexed account);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);


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

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) {
        require(initialSupply_ <= MAX_SUPPLY, "Token: initial supply exceeds maximum");

        _name = name_;
        _symbol = symbol_;
        _totalSupply = initialSupply_;
        _balances[_msgSender()] = initialSupply_;

        emit Transfer(address(0), _msgSender(), initialSupply_);
    }


    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
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

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function maxSupply() public pure returns (uint256) {
        return MAX_SUPPLY;
    }


    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(_msgSender())
        notBlacklisted(to)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        override
        whenNotPaused
        notBlacklisted(_msgSender())
        notBlacklisted(spender)
        validAddress(spender)
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenNotPaused
        notBlacklisted(_msgSender())
        notBlacklisted(spender)
        validAddress(spender)
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender).add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenNotPaused
        notBlacklisted(_msgSender())
        notBlacklisted(spender)
        validAddress(spender)
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "Token: decreased allowance below zero");
        _approve(owner, spender, currentAllowance.sub(subtractedValue));
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
        _mint(to, amount);
    }

    function burn(uint256 amount)
        public
        whenNotPaused
        notBlacklisted(_msgSender())
        validAmount(amount)
    {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address from, uint256 amount)
        public
        whenNotPaused
        notBlacklisted(from)
        validAmount(amount)
    {
        _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused();
    }

    function blacklist(address account) public onlyOwner validAddress(account) {
        require(!_blacklisted[account], "Token: account already blacklisted");
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function removeFromBlacklist(address account) public onlyOwner validAddress(account) {
        require(_blacklisted[account], "Token: account not blacklisted");
        _blacklisted[account] = false;
        emit RemovedFromBlacklist(account);
    }


    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Token: transfer from the zero address");
        require(to != address(0), "Token: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Token: transfer amount exceeds balance");

        _balances[from] = fromBalance.sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Token: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "Token: burn from the zero address");

        uint256 accountBalance = _balances[from];
        require(accountBalance >= amount, "Token: burn amount exceeds balance");

        _balances[from] = accountBalance.sub(amount);
        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Token: approve from the zero address");
        require(spender != address(0), "Token: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Token: insufficient allowance");
            _approve(owner, spender, currentAllowance.sub(amount));
        }
    }
}
