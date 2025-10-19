
pragma solidity ^0.8.0;

contract BadPracticeERC20Token {
    string public name = "Bad Practice Token";
    string public symbol = "BPT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    bool public paused = false;
    uint256 public maxTransferAmount = 10000 * 10**18;
    uint256 public minTransferAmount = 1 * 10**15;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Pause();
    event Unpause();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {

        require(msg.sender != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        require(!paused, "Contract is paused");
        require(value >= minTransferAmount, "Transfer amount too small");
        require(value <= maxTransferAmount, "Transfer amount too large");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {

        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        require(!paused, "Contract is paused");
        require(value >= minTransferAmount, "Transfer amount too small");
        require(value <= maxTransferAmount, "Transfer amount too large");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        require(!paused, "Contract is paused");

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        require(!paused, "Contract is paused");

        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        require(!paused, "Contract is paused");
        require(allowance[msg.sender][spender] >= subtractedValue, "Decreased allowance below zero");

        allowance[msg.sender][spender] -= subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function mint(address to, uint256 amount) external returns (bool) {

        require(msg.sender == owner, "Only owner can mint");
        require(to != address(0), "Mint to zero address");
        require(!paused, "Contract is paused");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        return true;
    }

    function burn(uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance to burn");
        require(!paused, "Contract is paused");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    function burnFrom(address from, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance to burn");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance to burn");
        require(!paused, "Contract is paused");

        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        totalSupply -= amount;

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

    function setMaxTransferAmount(uint256 newMaxAmount) external {

        require(msg.sender == owner, "Only owner can set max transfer amount");
        require(newMaxAmount > 0, "Max transfer amount must be greater than 0");

        maxTransferAmount = newMaxAmount;
    }

    function setMinTransferAmount(uint256 newMinAmount) external {

        require(msg.sender == owner, "Only owner can set min transfer amount");
        require(newMinAmount > 0, "Min transfer amount must be greater than 0");

        minTransferAmount = newMinAmount;
    }

    function transferOwnership(address newOwner) external {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");

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

    function batchTransfer(address[] memory recipients, uint256[] memory amounts) external returns (bool) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays");
        require(!paused, "Contract is paused");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance for batch transfer");

        for (uint256 i = 0; i < recipients.length; i++) {

            require(recipients[i] != address(0), "Transfer to zero address");
            require(amounts[i] >= minTransferAmount, "Transfer amount too small");
            require(amounts[i] <= maxTransferAmount, "Transfer amount too large");

            balanceOf[msg.sender] -= amounts[i];
            balanceOf[recipients[i]] += amounts[i];

            emit Transfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }

    function getTokenInfo() external view returns (string memory, string memory, uint8, uint256) {
        return (name, symbol, decimals, totalSupply);
    }

    function getOwnerInfo() external view returns (address, bool) {
        return (owner, paused);
    }

    function getTransferLimits() external view returns (uint256, uint256) {
        return (minTransferAmount, maxTransferAmount);
    }
}
