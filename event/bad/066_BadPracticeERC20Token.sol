
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
    event Mint(address to, uint256 amount);
    event Burn(address from, uint256 amount);


    error Failed();
    error NotAllowed();
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
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        _totalSupply = _initialSupply * 10**_decimals;
        _balances[msg.sender] = _totalSupply;
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

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        address oldOwner = owner;
        owner = newOwner;


    }

    function pause() public onlyOwner {
        paused = true;


    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0));
        _totalSupply += amount;
        _balances[to] += amount;


        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) public {
        address account = msg.sender;
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount);

        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;


        emit Transfer(account, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {

        require(from != address(0));
        require(to != address(0));

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount);

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
            require(currentAllowance >= amount);
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);
        payable(owner).transfer(balance);

    }

    receive() external payable {}
}
