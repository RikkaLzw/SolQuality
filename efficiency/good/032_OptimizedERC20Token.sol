
pragma solidity ^0.8.19;

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

contract OptimizedERC20Token is IERC20 {

    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 private _totalSupply;


    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public immutable owner;


    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
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


        _totalSupply = _initialSupply;
        _balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address ownerAddr, address spender) external view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {

        uint256 currentAllowance = _allowances[from][msg.sender];

        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");

            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }

        _transfer(from, to, amount);
        return true;
    }


    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");


        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Insufficient balance");


        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        require(ownerAddr != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }


    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Mint to zero address");


        unchecked {
            _totalSupply += amount;
            _balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }


    function burn(uint256 amount) external {
        address account = msg.sender;
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "Burn amount exceeds balance");

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
        emit Burn(account, amount);
    }


    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays");


        uint256 senderBalance = _balances[msg.sender];
        uint256 totalAmount = 0;


        uint256 recipientsLength = recipients.length;


        for (uint256 i = 0; i < recipientsLength;) {
            require(recipients[i] != address(0), "Transfer to zero address");
            totalAmount += amounts[i];
            unchecked { ++i; }
        }

        require(senderBalance >= totalAmount, "Insufficient balance");


        unchecked {
            _balances[msg.sender] = senderBalance - totalAmount;
        }


        for (uint256 i = 0; i < recipientsLength;) {
            unchecked {
                _balances[recipients[i]] += amounts[i];
            }
            emit Transfer(msg.sender, recipients[i], amounts[i]);
            unchecked { ++i; }
        }

        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        _approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
}
