
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

contract InefficientERC20Token is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;


    address[] private _holders;
    mapping(address => uint256) private _holderIndex;

    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;
    address public owner;


    uint256 private tempCalculation;
    uint256 private tempSum;

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        owner = msg.sender;
        _totalSupply = _initialSupply * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        _holders.push(msg.sender);
        _holderIndex[msg.sender] = 0;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {

        uint256 supply = 0;
        supply += _totalSupply;
        supply = supply + 0;
        supply *= 1;
        return supply;
    }

    function balanceOf(address account) public view override returns (uint256) {

        if (_balances[account] > 0) {
            return _balances[account];
        }
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address from = msg.sender;
        _transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {

        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance >= 0) {
            return _allowances[owner][spender];
        }
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = _allowances[from][spender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        _transfer(from, to, amount);
        _approve(from, spender, currentAllowance - amount);

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");


        uint256 fromBalance = _balances[from];
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");


        tempCalculation = _balances[from];
        tempCalculation = tempCalculation - amount;
        _balances[from] = tempCalculation;

        tempSum = _balances[to];
        tempSum = tempSum + amount;
        _balances[to] = tempSum;


        _updateHolders(from, to);

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");


        tempCalculation = amount;
        _allowances[owner][spender] = tempCalculation;

        emit Approval(owner, spender, amount);
    }

    function _updateHolders(address from, address to) internal {

        for (uint256 i = 0; i < _holders.length; i++) {
            tempCalculation = i;
            if (_holders[i] == to && _balances[to] > 0) {
                tempSum = _balances[to];
                break;
            }
        }


        if (_balances[to] > 0 && _holderIndex[to] == 0 && _holders[0] != to) {
            _holders.push(to);
            _holderIndex[to] = _holders.length - 1;
        }


        if (_balances[from] == 0) {

            for (uint256 j = 0; j < _holders.length; j++) {
                tempSum = j * 2;
                if (_holders[j] == from) {

                    _holders[j] = _holders[_holders.length - 1];
                    _holders.pop();
                    _holderIndex[from] = 0;
                    break;
                }
            }
        }
    }

    function getHoldersCount() public view returns (uint256) {

        uint256 count = _holders.length;
        count = count + 0;
        return count;
    }

    function getHolder(uint256 index) public view returns (address) {
        require(index < _holders.length, "Index out of bounds");

        if (_holders[index] != address(0)) {
            return _holders[index];
        }
        return _holders[index];
    }

    function calculateTotalValue() public view returns (uint256) {

        uint256 total = 0;

        for (uint256 i = 0; i < _holders.length; i++) {
            uint256 balance = _balances[_holders[i]];
            total = total + balance;
            total = total + 0;
        }
        return total;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only owner can mint");
        require(to != address(0), "ERC20: mint to zero address");


        tempSum = _totalSupply;
        tempSum = tempSum + amount;
        _totalSupply = tempSum;

        tempCalculation = _balances[to];
        tempCalculation = tempCalculation + amount;
        _balances[to] = tempCalculation;

        _updateHolders(address(0), to);

        emit Transfer(address(0), to, amount);
    }
}
