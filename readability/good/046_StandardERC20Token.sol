
pragma solidity ^0.8.0;


contract StandardERC20Token {

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;


    mapping(address => uint256) private balances;


    mapping(address => mapping(address => uint256)) private allowances;


    address public owner;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 initialSupply
    ) {
        name = tokenName;
        symbol = tokenSymbol;
        decimals = tokenDecimals;
        totalSupply = initialSupply * 10**tokenDecimals;
        owner = msg.sender;


        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }


    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }


    function transfer(address to, uint256 amount) public returns (bool) {
        address sender = msg.sender;
        require(sender != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balances[sender] >= amount, "Insufficient balance");

        balances[sender] -= amount;
        balances[to] += amount;

        emit Transfer(sender, to, amount);
        return true;
    }


    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return allowances[tokenOwner][spender];
    }


    function approve(address spender, uint256 amount) public returns (bool) {
        address tokenOwner = msg.sender;
        require(tokenOwner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        allowances[tokenOwner][spender] = amount;

        emit Approval(tokenOwner, spender, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balances[from] >= amount, "Insufficient balance");
        require(allowances[from][spender] >= amount, "Insufficient allowance");

        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][spender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address tokenOwner = msg.sender;
        require(spender != address(0), "Increase allowance to zero address");

        allowances[tokenOwner][spender] += addedValue;

        emit Approval(tokenOwner, spender, allowances[tokenOwner][spender]);
        return true;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address tokenOwner = msg.sender;
        require(spender != address(0), "Decrease allowance to zero address");
        require(allowances[tokenOwner][spender] >= subtractedValue, "Decreased allowance below zero");

        allowances[tokenOwner][spender] -= subtractedValue;

        emit Approval(tokenOwner, spender, allowances[tokenOwner][spender]);
        return true;
    }


    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Mint to zero address");

        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }


    function burn(uint256 amount) public {
        address account = msg.sender;
        require(balances[account] >= amount, "Burn amount exceeds balance");

        balances[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }


    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }


    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
