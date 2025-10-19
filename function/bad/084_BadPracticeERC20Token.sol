
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

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        name = "BadPractice Token";
        symbol = "BAD";
        decimals = 18;
        _totalSupply = 1000000 * 10**decimals;
        owner = msg.sender;
        paused = false;
        maxTransferAmount = 10000 * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }




    function multiPurposeFunction(
        address to,
        uint256 amount,
        bool shouldPause,
        uint256 newMaxAmount,
        address newOwner,
        string memory newName
    ) public onlyOwner {

        if (to != address(0) && amount > 0) {
            require(_balances[msg.sender] >= amount, "Insufficient balance");
            _balances[msg.sender] -= amount;
            _balances[to] += amount;
            emit Transfer(msg.sender, to, amount);
        }


        if (shouldPause != paused) {
            paused = shouldPause;
        }


        if (newMaxAmount > 0) {
            maxTransferAmount = newMaxAmount;
        }


        if (newOwner != address(0) && newOwner != owner) {
            owner = newOwner;
        }


        if (bytes(newName).length > 0) {
            name = newName;
        }
    }


    function calculateFee(uint256 amount) public pure returns (uint256) {
        return (amount * 1) / 100;
    }

    function validateTransfer(address from, address to, uint256 amount) public view returns (bool) {
        return from != address(0) && to != address(0) && amount > 0 && amount <= _balances[from];
    }


    function complexTransfer(address to, uint256 amount) public returns (bool) {
        require(!paused, "Contract is paused");

        if (to != address(0)) {
            if (amount > 0) {
                if (_balances[msg.sender] >= amount) {
                    if (amount <= maxTransferAmount) {
                        uint256 fee = calculateFee(amount);
                        uint256 transferAmount = amount - fee;

                        if (transferAmount > 0) {
                            if (validateTransfer(msg.sender, to, transferAmount)) {
                                if (fee > 0) {
                                    if (_balances[msg.sender] >= amount) {
                                        _balances[msg.sender] -= amount;
                                        _balances[to] += transferAmount;
                                        _balances[owner] += fee;

                                        emit Transfer(msg.sender, to, transferAmount);
                                        if (fee > 0) {
                                            emit Transfer(msg.sender, owner, fee);
                                        }
                                        return true;
                                    }
                                } else {
                                    _balances[msg.sender] -= transferAmount;
                                    _balances[to] += transferAmount;
                                    emit Transfer(msg.sender, to, transferAmount);
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
        }
        return false;
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

    function pauseContract() public onlyOwner {
        paused = true;
    }

    function unpauseContract() public onlyOwner {
        paused = false;
    }

    function setMaxTransferAmount(uint256 amount) public onlyOwner {
        maxTransferAmount = amount;
    }
}
