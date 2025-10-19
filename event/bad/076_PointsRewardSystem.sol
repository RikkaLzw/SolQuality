
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => bool) public authorizedMinters;
    mapping(address => uint256) public lastRewardTime;

    uint256 public constant DAILY_REWARD = 100;
    uint256 public constant MIN_TRANSFER_AMOUNT = 1;
    uint256 public constant MAX_MINT_AMOUNT = 10000;

    error NotOwner();
    error NotAuth();
    error BadAmount();
    error TooSoon();
    error NoBalance();

    event Transfer(address from, address to, uint256 amount);
    event Mint(address to, uint256 amount);
    event Burn(address from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedMinters[msg.sender] = true;
    }

    function addAuthorizedMinter(address minter) external onlyOwner {
        require(minter != address(0));
        authorizedMinters[minter] = true;
    }

    function removeAuthorizedMinter(address minter) external onlyOwner {
        require(minter != address(0));
        authorizedMinters[minter] = false;
    }

    function mint(address to, uint256 amount) external onlyAuthorized {
        require(to != address(0));
        require(amount > 0 && amount <= MAX_MINT_AMOUNT);

        balances[to] += amount;
        totalSupply += amount;

        emit Mint(to, amount);
    }

    function burn(uint256 amount) external {
        require(balances[msg.sender] >= amount);
        require(amount > 0);

        balances[msg.sender] -= amount;
        totalSupply -= amount;

        emit Burn(msg.sender, amount);
    }

    function transfer(address to, uint256 amount) external {
        require(to != address(0));
        require(balances[msg.sender] >= amount);
        require(amount >= MIN_TRANSFER_AMOUNT);

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    function claimDailyReward() external {
        require(block.timestamp >= lastRewardTime[msg.sender] + 1 days);

        lastRewardTime[msg.sender] = block.timestamp;
        balances[msg.sender] += DAILY_REWARD;
        totalSupply += DAILY_REWARD;
    }

    function exchangePoints(uint256 pointsToExchange) external {
        require(pointsToExchange > 0);
        require(balances[msg.sender] >= pointsToExchange);

        balances[msg.sender] -= pointsToExchange;
        totalSupply -= pointsToExchange;
    }

    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length);
        require(recipients.length > 0);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(balances[msg.sender] >= totalAmount);

        balances[msg.sender] -= totalAmount;

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0));
            require(amounts[i] >= MIN_TRANSFER_AMOUNT);
            balances[recipients[i]] += amounts[i];
        }
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }

    function canClaimReward(address account) external view returns (bool) {
        return block.timestamp >= lastRewardTime[account] + 1 days;
    }
}
