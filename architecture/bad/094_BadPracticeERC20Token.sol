
pragma solidity ^0.8.0;

contract BadPracticeERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    address public owner;
    bool public paused;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Pause();
    event Unpause();

    constructor() {
        name = "BadPractice Token";
        symbol = "BAD";
        decimals = 18;
        totalSupply = 1000000 * 10**18;
        owner = msg.sender;
        paused = false;
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) public returns (bool) {

        if (paused) {
            revert("Token is paused");
        }
        if (msg.sender == address(0)) {
            revert("Transfer from zero address");
        }
        if (to == address(0)) {
            revert("Transfer to zero address");
        }
        if (balances[msg.sender] < amount) {
            revert("Insufficient balance");
        }

        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {

        if (paused) {
            revert("Token is paused");
        }
        if (msg.sender == address(0)) {
            revert("Approve from zero address");
        }
        if (spender == address(0)) {
            revert("Approve to zero address");
        }

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {

        if (paused) {
            revert("Token is paused");
        }
        if (from == address(0)) {
            revert("Transfer from zero address");
        }
        if (to == address(0)) {
            revert("Transfer to zero address");
        }
        if (balances[from] < amount) {
            revert("Insufficient balance");
        }
        if (allowances[from][msg.sender] < amount) {
            revert("Insufficient allowance");
        }

        balances[from] = balances[from] - amount;
        balances[to] = balances[to] + amount;
        allowances[from][msg.sender] = allowances[from][msg.sender] - amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return allowances[tokenOwner][spender];
    }


    function mint(address to, uint256 amount) public {

        if (msg.sender != owner) {
            revert("Only owner can mint");
        }
        if (paused) {
            revert("Token is paused");
        }
        if (to == address(0)) {
            revert("Mint to zero address");
        }
        if (totalSupply + amount > 10000000 * 10**18) {
            revert("Exceeds max supply");
        }

        totalSupply = totalSupply + amount;
        balances[to] = balances[to] + amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) public {

        if (paused) {
            revert("Token is paused");
        }
        if (balances[msg.sender] < amount) {
            revert("Insufficient balance to burn");
        }

        balances[msg.sender] = balances[msg.sender] - amount;
        totalSupply = totalSupply - amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function pause() public {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }
        if (paused) {
            revert("Already paused");
        }

        paused = true;
        emit Pause();
    }

    function unpause() public {

        if (msg.sender != owner) {
            revert("Only owner can unpause");
        }
        if (!paused) {
            revert("Not paused");
        }

        paused = false;
        emit Unpause();
    }

    function transferOwnership(address newOwner) public {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = newOwner;
    }


    function batchTransfer(address[] memory recipients, uint256[] memory amounts) public {

        if (paused) {
            revert("Token is paused");
        }
        if (recipients.length != amounts.length) {
            revert("Arrays length mismatch");
        }
        if (recipients.length > 100) {
            revert("Too many recipients");
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount + amounts[i];
        }


        if (balances[msg.sender] < totalAmount) {
            revert("Insufficient balance for batch transfer");
        }

        balances[msg.sender] = balances[msg.sender] - totalAmount;

        for (uint256 i = 0; i < recipients.length; i++) {

            if (recipients[i] == address(0)) {
                revert("Transfer to zero address");
            }

            balances[recipients[i]] = balances[recipients[i]] + amounts[i];
            emit Transfer(msg.sender, recipients[i], amounts[i]);
        }
    }


    function transferWithFee(address to, uint256 amount) public {

        if (paused) {
            revert("Token is paused");
        }
        if (msg.sender == address(0)) {
            revert("Transfer from zero address");
        }
        if (to == address(0)) {
            revert("Transfer to zero address");
        }

        uint256 fee = amount * 1 / 100;
        uint256 transferAmount = amount - fee;


        if (balances[msg.sender] < amount) {
            revert("Insufficient balance");
        }

        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + transferAmount;
        balances[owner] = balances[owner] + fee;

        emit Transfer(msg.sender, to, transferAmount);
        emit Transfer(msg.sender, owner, fee);
    }


    mapping(address => uint256) public lockTime;

    function lockTokens(uint256 duration) public {

        if (paused) {
            revert("Token is paused");
        }
        if (duration > 365 * 24 * 60 * 60) {
            revert("Lock duration too long");
        }

        lockTime[msg.sender] = block.timestamp + duration;
    }

    function transferWithLockCheck(address to, uint256 amount) public {

        if (paused) {
            revert("Token is paused");
        }
        if (msg.sender == address(0)) {
            revert("Transfer from zero address");
        }
        if (to == address(0)) {
            revert("Transfer to zero address");
        }
        if (block.timestamp < lockTime[msg.sender]) {
            revert("Tokens are locked");
        }
        if (balances[msg.sender] < amount) {
            revert("Insufficient balance");
        }

        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + amount;
        emit Transfer(msg.sender, to, amount);
    }
}
