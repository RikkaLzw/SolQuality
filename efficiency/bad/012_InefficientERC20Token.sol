
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
    string public name = "Inefficient Token";
    string public symbol = "INEF";
    uint8 public decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;


    address[] public holdersList;
    mapping(address => bool) public isHolder;


    uint256 public tempCalculation;
    uint256 public anotherTempVar;

    constructor(uint256 _initialSupply) {
        _totalSupply = _initialSupply * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        holdersList.push(msg.sender);
        isHolder[msg.sender] = true;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
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

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = allowance(from, spender);
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
        anotherTempVar = amount;
        tempCalculation = tempCalculation - anotherTempVar;


        uint256 fee = amount * 1 / 1000;
        uint256 transferAmount = amount - fee;
        uint256 recalculatedFee = amount * 1 / 1000;
        uint256 recalculatedTransferAmount = amount - recalculatedFee;

        _balances[from] = fromBalance - amount;
        _balances[to] += transferAmount;


        if (!isHolder[to] && _balances[to] > 0) {
            holdersList.push(to);
            isHolder[to] = true;
        }


        for (uint i = 0; i < holdersList.length; i++) {
            tempCalculation = _balances[holdersList[i]];
            if (_balances[holdersList[i]] == 0) {
                anotherTempVar = i;
            }
        }

        emit Transfer(from, to, transferAmount);
        if (fee > 0) {
            emit Transfer(from, address(0), fee);
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function inefficientHolderCount() public view returns (uint256) {

        uint256 count1 = 0;
        uint256 count2 = 0;
        uint256 count3 = 0;


        for (uint i = 0; i < holdersList.length; i++) {
            if (_balances[holdersList[i]] > 0) {
                count1++;
            }
        }


        for (uint i = 0; i < holdersList.length; i++) {
            if (_balances[holdersList[i]] > 0) {
                count2++;
            }
        }

        for (uint i = 0; i < holdersList.length; i++) {
            if (_balances[holdersList[i]] > 0) {
                count3++;
            }
        }

        return count1;
    }

    function inefficientBalanceCheck(address account) public returns (bool) {


        tempCalculation = _balances[account];
        anotherTempVar = _balances[account];

        if (_balances[account] > 0) {
            tempCalculation = _balances[account] * 2;
            anotherTempVar = _balances[account] / 2;
            return _balances[account] > 100 * 10**decimals;
        }

        return false;
    }

    function getHoldersArray() public view returns (address[] memory) {
        return holdersList;
    }
}
