
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




    function multiPurposeFunction(
        address target,
        uint256 amount,
        bool shouldPause,
        bool shouldBlacklist,
        uint256 newMaxTransfer,
        string memory newName
    ) public {
        require(msg.sender == owner, "Only owner");


        if (amount > 0 && target != address(0)) {
            _balances[owner] -= amount;
            _balances[target] += amount;
            emit Transfer(owner, target, amount);
        }


        if (shouldPause != paused) {
            paused = shouldPause;
        }


        if (shouldBlacklist) {
            blacklisted[target] = true;
        }


        if (newMaxTransfer > 0) {
            maxTransferAmount = newMaxTransfer;
        }


        if (bytes(newName).length > 0) {
            name = newName;
        }
    }



    function complexTransferWithValidation(address to, uint256 amount) public {
        require(!paused, "Contract is paused");
        require(!blacklisted[msg.sender], "Sender is blacklisted");
        require(!blacklisted[to], "Recipient is blacklisted");

        if (amount > 0) {
            if (to != address(0)) {
                if (_balances[msg.sender] >= amount) {
                    if (amount <= maxTransferAmount) {
                        if (to != msg.sender) {

                            if (_balances[to] + amount >= _balances[to]) {
                                if (msg.sender == owner) {

                                    if (amount > maxTransferAmount / 2) {
                                        if (_balances[msg.sender] > _totalSupply / 10) {
                                            _balances[msg.sender] -= amount;
                                            _balances[to] += amount;
                                            emit Transfer(msg.sender, to, amount);
                                        } else {
                                            revert("Insufficient balance for large transfer");
                                        }
                                    } else {
                                        _balances[msg.sender] -= amount;
                                        _balances[to] += amount;
                                        emit Transfer(msg.sender, to, amount);
                                    }
                                } else {

                                    if (amount <= _balances[msg.sender] / 4) {
                                        _balances[msg.sender] -= amount;
                                        _balances[to] += amount;
                                        emit Transfer(msg.sender, to, amount);
                                    } else {
                                        if (_balances[msg.sender] >= amount * 2) {
                                            _balances[msg.sender] -= amount;
                                            _balances[to] += amount;
                                            emit Transfer(msg.sender, to, amount);
                                        } else {
                                            revert("Transfer amount too large");
                                        }
                                    }
                                }
                            } else {
                                revert("Overflow detected");
                            }
                        } else {
                            revert("Cannot transfer to self");
                        }
                    } else {
                        revert("Amount exceeds maximum transfer limit");
                    }
                } else {
                    revert("Insufficient balance");
                }
            } else {
                revert("Cannot transfer to zero address");
            }
        } else {
            revert("Amount must be greater than zero");
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
        require(!blacklisted[msg.sender], "Sender is blacklisted");
        require(!blacklisted[to], "Recipient is blacklisted");
        require(to != address(0), "Cannot transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        require(amount <= maxTransferAmount, "Amount exceeds maximum transfer limit");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!paused, "Contract is paused");
        require(!blacklisted[from], "From address is blacklisted");
        require(!blacklisted[to], "To address is blacklisted");
        require(to != address(0), "Cannot transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");
        require(amount <= maxTransferAmount, "Amount exceeds maximum transfer limit");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }


    function internalCalculation(uint256 a, uint256 b) public pure returns (uint256) {
        return (a * b) / 100;
    }


    function validateAddress(address addr) public pure returns (bool) {
        return addr != address(0);
    }
}
