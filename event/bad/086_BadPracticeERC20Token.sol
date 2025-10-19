
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

contract BadPracticeERC20Token is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;
    address public owner;
    bool public paused;


    event OwnershipTransferred(address previousOwner, address newOwner);
    event Paused(address account);
    event Unpaused(address account);


    error Failed();
    error Invalid();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _totalSupply = _totalSupply * 10**_decimals;
        _balances[msg.sender] = _totalSupply;
        owner = msg.sender;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0));

        _totalSupply += amount;
        _balances[to] += amount;


        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) public {
        address account = msg.sender;
        require(_balances[account] >= amount);

        _balances[account] -= amount;
        _totalSupply -= amount;


        emit Transfer(account, address(0), amount);
    }

    function pause() public onlyOwner {

        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {

        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));

        address oldOwner = owner;
        owner = newOwner;



    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0));
        require(to != address(0));

        uint256 fromBalance = _balances[from];

        if (fromBalance < amount) {
            revert Invalid();
        }

        _balances[from] = fromBalance - amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0));
        require(spender != address(0));

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {

            if (currentAllowance < amount) {
                revert Failed();
            }
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}
