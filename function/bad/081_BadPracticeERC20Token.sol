
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
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    bool private _paused;
    mapping(address => bool) private _blacklisted;
    uint256 private _maxTransactionAmount;
    uint256 private _fee;

    constructor() {
        _name = "BadPracticeToken";
        _symbol = "BPT";
        _decimals = 18;
        _totalSupply = 1000000 * 10**_decimals;
        _owner = msg.sender;
        _balances[msg.sender] = _totalSupply;
        _maxTransactionAmount = _totalSupply / 100;
        _fee = 1;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }




    function complexTransferWithMultipleChecks(
        address from,
        address to,
        uint256 amount,
        bool applyFee,
        bool checkBlacklist,
        bool checkPause,
        uint256 customFee
    ) public returns (bool success, uint256 actualAmount, string memory status) {
        if (checkPause) {
            if (_paused) {
                if (msg.sender == _owner) {
                    if (checkBlacklist) {
                        if (_blacklisted[from] || _blacklisted[to]) {
                            if (from == _owner || to == _owner) {

                            } else {
                                return (false, 0, "Blacklisted");
                            }
                        }
                    }
                } else {
                    return (false, 0, "Paused");
                }
            } else {
                if (checkBlacklist) {
                    if (_blacklisted[from] || _blacklisted[to]) {
                        return (false, 0, "Blacklisted");
                    }
                }
            }
        }

        uint256 finalAmount = amount;
        if (applyFee) {
            uint256 feeAmount = customFee > 0 ? customFee : _fee;
            if (amount > feeAmount) {
                finalAmount = amount - feeAmount;
                if (_balances[from] >= amount) {
                    _balances[from] -= amount;
                    _balances[to] += finalAmount;
                    _balances[_owner] += feeAmount;
                    emit Transfer(from, to, finalAmount);
                    emit Transfer(from, _owner, feeAmount);
                    return (true, finalAmount, "Transfer with fee completed");
                } else {
                    return (false, 0, "Insufficient balance");
                }
            } else {
                return (false, 0, "Amount too small for fee");
            }
        } else {
            if (_balances[from] >= finalAmount) {
                _balances[from] -= finalAmount;
                _balances[to] += finalAmount;
                emit Transfer(from, to, finalAmount);
                return (true, finalAmount, "Transfer completed");
            } else {
                return (false, 0, "Insufficient balance");
            }
        }
    }



    function updateTokenParameters(
        string memory newName,
        string memory newSymbol,
        uint256 newMaxTransaction,
        uint256 newFee,
        bool pauseState
    ) public {
        require(msg.sender == _owner, "Not owner");
        _name = newName;
        _symbol = newSymbol;
        _maxTransactionAmount = newMaxTransaction;
        _fee = newFee;
        _paused = pauseState;

    }


    function calculateTransferAmount(uint256 amount, bool withFee) public view returns (uint256) {
        if (withFee) {
            return amount > _fee ? amount - _fee : 0;
        }
        return amount;
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

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        require(amount <= _maxTransactionAmount, "Amount exceeds max transaction");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "Approve to zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");
        require(amount <= _maxTransactionAmount, "Amount exceeds max transaction");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function setBlacklist(address account, bool status) public {
        require(msg.sender == _owner, "Not owner");
        _blacklisted[account] = status;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function pause() public {
        require(msg.sender == _owner, "Not owner");
        _paused = true;
    }

    function unpause() public {
        require(msg.sender == _owner, "Not owner");
        _paused = false;
    }

    function isPaused() public view returns (bool) {
        return _paused;
    }
}
