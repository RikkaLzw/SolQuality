
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


    function mint(address to, uint256 amount) external {

        require(msg.sender == owner, "Only owner can mint");
        require(!paused, "Token operations are paused");
        require(to != address(0), "Cannot mint to zero address");
        require(totalSupply + amount <= 10000000 * 10**18, "Exceeds maximum supply");

        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }


    function burn(uint256 amount) external {

        require(!paused, "Token operations are paused");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance to burn");
        require(amount >= 1000 * 10**18, "Minimum burn amount is 1000 tokens");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }


    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external {

        require(!paused, "Token transfers are paused");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 100, "Too many recipients");

        for (uint256 i = 0; i < recipients.length; i++) {

            require(recipients[i] != address(0), "Cannot transfer to zero address");
            require(balanceOf[msg.sender] >= amounts[i], "Insufficient balance");


            balanceOf[msg.sender] -= amounts[i];
            balanceOf[recipients[i]] += amounts[i];
            emit Transfer(msg.sender, recipients[i], amounts[i]);
        }
    }


    function getTokenInfo() public view returns (string memory, string memory, uint8, uint256) {
        return (name, symbol, decimals, totalSupply);
    }


    function emergencyWithdraw() external {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(block.timestamp > 1735689600, "Emergency withdraw not available yet");

        uint256 contractBalance = address(this).balance;
        if (contractBalance > 0) {
            payable(owner).transfer(contractBalance);
        }
    }


    receive() external payable {

    }

    fallback() external payable {

    }
}
