
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

    constructor() {
        name = "BadPractice Token";
        symbol = "BAD";
        decimals = 18;
        _totalSupply = 1000000 * 10**decimals;
        owner = msg.sender;
        _balances[msg.sender] = _totalSupply;
        paused = false;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }




    function complexMultiPurposeFunction(
        address target,
        uint256 amount,
        bool shouldTransfer,
        bool shouldApprove,
        address spender,
        uint256 approvalAmount,
        bool shouldPause
    ) public {

        if (msg.sender == owner) {
            if (shouldPause) {
                if (paused) {
                    paused = false;
                } else {
                    paused = true;
                }
            }

            if (shouldTransfer) {
                if (target != address(0)) {
                    if (amount > 0) {
                        if (_balances[msg.sender] >= amount) {
                            if (!paused) {
                                _balances[msg.sender] -= amount;
                                _balances[target] += amount;
                                emit Transfer(msg.sender, target, amount);
                            }
                        }
                    }
                }
            }

            if (shouldApprove) {
                if (spender != address(0)) {
                    if (approvalAmount >= 0) {
                        if (!paused) {
                            _allowances[msg.sender][spender] = approvalAmount;
                            emit Approval(msg.sender, spender, approvalAmount);
                        }
                    }
                }
            }
        }
    }


    function calculateBalance(address account) public view returns (uint256) {
        return _balances[account];
    }


    function validateTransfer(address from, address to, uint256 amount) public view returns (bool) {
        if (paused) return false;
        if (from == address(0) || to == address(0)) return false;
        if (amount == 0) return false;
        if (_balances[from] < amount) return false;
        return true;
    }


    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!paused, "Token is paused");
        require(to != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(!paused, "Token is paused");
        require(spender != address(0), "Approve to zero address");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!paused, "Token is paused");
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


    function complexTokenOperation(address recipient, uint256 baseAmount) public returns (bool) {
        if (msg.sender == owner) {
            if (!paused) {
                if (recipient != address(0)) {
                    if (baseAmount > 0) {
                        uint256 finalAmount = baseAmount;
                        if (_balances[msg.sender] >= baseAmount) {
                            if (baseAmount > 1000 * 10**decimals) {
                                if (_totalSupply > 500000 * 10**decimals) {
                                    finalAmount = baseAmount + (baseAmount * 5 / 100);
                                } else {
                                    finalAmount = baseAmount + (baseAmount * 3 / 100);
                                }
                            } else {
                                if (baseAmount > 100 * 10**decimals) {
                                    finalAmount = baseAmount + (baseAmount * 2 / 100);
                                }
                            }

                            if (_balances[msg.sender] >= finalAmount) {
                                _balances[msg.sender] -= finalAmount;
                                _balances[recipient] += finalAmount;
                                emit Transfer(msg.sender, recipient, finalAmount);
                                return true;
                            }
                        }
                    }
                }
            }
        }
        return false;
    }
}
