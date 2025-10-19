
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
    uint256 public maxTransferAmount;
    mapping(address => bool) public blacklisted;

    constructor() {
        name = "BadPracticeToken";
        symbol = "BPT";
        decimals = 18;
        _totalSupply = 1000000 * 10**decimals;
        owner = msg.sender;
        _balances[msg.sender] = _totalSupply;
        paused = false;
        maxTransferAmount = 10000 * 10**decimals;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }




    function complexAdminFunction(
        address target,
        uint256 amount,
        bool shouldPause,
        bool shouldBlacklist,
        uint256 newMaxTransfer,
        string memory newName
    ) public onlyOwner {

        if (shouldPause) {
            if (!paused) {
                paused = true;
            } else {
                paused = false;
            }
        }


        if (shouldBlacklist) {
            if (target != address(0)) {
                if (!blacklisted[target]) {
                    blacklisted[target] = true;
                } else {
                    blacklisted[target] = false;
                }
            }
        }


        if (newMaxTransfer > 0) {
            if (newMaxTransfer <= _totalSupply) {
                if (newMaxTransfer >= 1000 * 10**decimals) {
                    maxTransferAmount = newMaxTransfer;
                }
            }
        }


        if (bytes(newName).length > 0) {
            if (bytes(newName).length <= 32) {
                name = newName;
            }
        }


        if (amount > 0) {
            if (target != address(0)) {
                if (_balances[target] + amount >= _balances[target]) {
                    _balances[target] += amount;
                    _totalSupply += amount;
                    emit Transfer(address(0), target, amount);
                }
            }
        }
    }



    function checkTransferConditions(address from, address to, uint256 amount) public view {
        require(!paused, "Token transfers are paused");
        require(!blacklisted[from], "Sender is blacklisted");
        require(!blacklisted[to], "Recipient is blacklisted");
        require(amount <= maxTransferAmount, "Amount exceeds maximum transfer limit");
        require(_balances[from] >= amount, "Insufficient balance");
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        address from = msg.sender;

        if (!paused) {
            if (!blacklisted[from]) {
                if (!blacklisted[to]) {
                    if (amount <= maxTransferAmount) {
                        if (_balances[from] >= amount) {
                            if (to != address(0)) {
                                if (amount > 0) {
                                    _balances[from] -= amount;
                                    _balances[to] += amount;
                                    emit Transfer(from, to, amount);
                                    return true;
                                } else {
                                    return false;
                                }
                            } else {
                                revert("Transfer to zero address");
                            }
                        } else {
                            revert("Insufficient balance");
                        }
                    } else {
                        revert("Amount exceeds maximum transfer limit");
                    }
                } else {
                    revert("Recipient is blacklisted");
                }
            } else {
                revert("Sender is blacklisted");
            }
        } else {
            revert("Token transfers are paused");
        }
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!paused) {
            if (!blacklisted[from]) {
                if (!blacklisted[to]) {
                    if (amount <= maxTransferAmount) {
                        if (_balances[from] >= amount) {
                            if (_allowances[from][msg.sender] >= amount) {
                                if (to != address(0)) {
                                    if (amount > 0) {
                                        _balances[from] -= amount;
                                        _balances[to] += amount;
                                        _allowances[from][msg.sender] -= amount;
                                        emit Transfer(from, to, amount);
                                        return true;
                                    } else {
                                        return false;
                                    }
                                } else {
                                    revert("Transfer to zero address");
                                }
                            } else {
                                revert("Insufficient allowance");
                            }
                        } else {
                            revert("Insufficient balance");
                        }
                    } else {
                        revert("Amount exceeds maximum transfer limit");
                    }
                } else {
                    revert("Recipient is blacklisted");
                }
            } else {
                revert("Sender is blacklisted");
            }
        } else {
            revert("Token transfers are paused");
        }
    }



    function getTokenInfoAndUserStatus(address user) public view returns (uint256, uint256, bool, bool, string memory) {

        uint256 userBalance = _balances[user];
        uint256 supply = _totalSupply;


        bool isBlacklisted = blacklisted[user];
        bool isPaused = paused;


        string memory tokenName = name;

        return (userBalance, supply, isBlacklisted, isPaused, tokenName);
    }
}
