
pragma solidity ^0.8.0;

contract BadPracticeERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    bool public paused;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Pause();
    event Unpause();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        name = "BadPractice Token";
        symbol = "BAD";
        decimals = 18;
        totalSupply = 1000000 * 10**18;
        owner = msg.sender;
        paused = false;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {

        require(!paused, "Token transfers are paused");
        require(to != address(0), "Cannot transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");


        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {

        require(!paused, "Token transfers are paused");
        require(to != address(0), "Cannot transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");


        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {

        require(!paused, "Token operations are paused");
        require(spender != address(0), "Cannot approve zero address");

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {

        require(!paused, "Token operations are paused");
        require(spender != address(0), "Cannot approve zero address");

        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {

        require(!paused, "Token operations are paused");
        require(spender != address(0), "Cannot approve zero address");
        require(allowance[msg.sender][spender] >= subtractedValue, "Decreased allowance below zero");

        allowance[msg.sender][spender] -= subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function mint(address to, uint256 amount) external returns (bool) {

        require(msg.sender == owner, "Only owner can mint");
        require(!paused, "Token operations are paused");
        require(to != address(0), "Cannot mint to zero address");
        require(totalSupply + amount <= 10000000 * 10**18, "Exceeds max supply");

        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        return true;
    }

    function burn(uint256 amount) external returns (bool) {

        require(!paused, "Token operations are paused");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance to burn");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    function burnFrom(address from, uint256 amount) external returns (bool) {

        require(!paused, "Token operations are paused");
        require(balanceOf[from] >= amount, "Insufficient balance to burn");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance to burn");

        balanceOf[from] -= amount;
        totalSupply -= amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, address(0), amount);
        return true;
    }

    function pause() external {

        require(msg.sender == owner, "Only owner can pause");
        require(!paused, "Already paused");

        paused = true;
        emit Pause();
    }

    function unpause() external {

        require(msg.sender == owner, "Only owner can unpause");
        require(paused, "Not paused");

        paused = false;
        emit Unpause();
    }

    function transferOwnership(address newOwner) external {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != owner, "New owner must be different");

        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function renounceOwnership() external {

        require(msg.sender == owner, "Only owner can renounce ownership");

        address previousOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    function emergencyWithdraw() external {

        require(msg.sender == owner, "Only owner can emergency withdraw");

        payable(owner).transfer(address(this).balance);
    }

    function setTokenDetails(string memory newName, string memory newSymbol) external {

        require(msg.sender == owner, "Only owner can set token details");
        require(!paused, "Token operations are paused");

        name = newName;
        symbol = newSymbol;
    }

    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external returns (bool) {

        require(!paused, "Token transfers are paused");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 100, "Too many recipients");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance for batch transfer");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot transfer to zero address");

            balanceOf[msg.sender] -= amounts[i];
            balanceOf[recipients[i]] += amounts[i];
            emit Transfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }

    receive() external payable {}

    fallback() external payable {}
}
