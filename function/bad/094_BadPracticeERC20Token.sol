
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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(bool isPaused);

    constructor() {
        name = "BadPracticeToken";
        symbol = "BPT";
        decimals = 18;
        _totalSupply = 1000000 * 10**decimals;
        owner = msg.sender;
        paused = false;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }




    function multiPurposeFunction(
        address target,
        uint256 amount,
        bool shouldPause,
        bool shouldTransferOwnership,
        address newOwner,
        bool shouldMint
    ) public returns (uint256, bool, address) {
        require(msg.sender == owner, "Not owner");

        uint256 resultAmount = 0;
        bool operationSuccess = false;
        address resultAddress = address(0);


        if (shouldPause) {
            paused = !paused;
            emit Paused(paused);
            operationSuccess = true;
        }


        if (shouldTransferOwnership && newOwner != address(0)) {
            address previousOwner = owner;
            owner = newOwner;
            emit OwnershipTransferred(previousOwner, newOwner);
            resultAddress = newOwner;
            operationSuccess = true;
        }


        if (shouldMint && amount > 0) {
            _totalSupply += amount;
            _balances[target] += amount;
            resultAmount = amount;
            emit Transfer(address(0), target, amount);
            operationSuccess = true;
        }

        return (resultAmount, operationSuccess, resultAddress);
    }


    function complexTransferLogic(address to, uint256 amount) public {
        require(!paused, "Contract is paused");
        require(to != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        if (amount > 0) {
            if (to != msg.sender) {
                if (_balances[to] == 0) {
                    if (amount >= 100 * 10**decimals) {
                        if (msg.sender == owner) {
                            if (_totalSupply > 500000 * 10**decimals) {

                                uint256 bonus = amount / 100;
                                if (bonus > 0) {
                                    _totalSupply += bonus;
                                    _balances[to] += bonus;
                                    emit Transfer(address(0), to, bonus);
                                }
                            }
                        }
                    }
                }
            }
        }

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
    }


    function ambiguousFunction(address account) public view returns (uint256) {
        if (account == owner) {
            return _balances[account];
        } else if (_balances[account] > 1000 * 10**decimals) {
            return 1;
        } else if (_balances[account] > 0) {
            return 2;
        }

    }


    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!paused, "Contract is paused");
        require(to != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(!paused, "Contract is paused");
        require(spender != address(0), "Approve to zero address");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!paused, "Contract is paused");
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }
}
