
pragma solidity ^0.8.0;


contract PointsRewardSystem {

    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public paused;


    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public authorized;
    mapping(address => bool) public blacklisted;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed recipient, uint256 indexed amount, string reason);
    event PointsDeducted(address indexed account, uint256 indexed amount, string reason);
    event AuthorizedAdded(address indexed account);
    event AuthorizedRemoved(address indexed account);
    event AccountBlacklisted(address indexed account);
    event AccountWhitelisted(address indexed account);
    event ContractPaused();
    event ContractUnpaused();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "PointsRewardSystem: caller is not the owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "PointsRewardSystem: caller is not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "PointsRewardSystem: contract is paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "PointsRewardSystem: account is blacklisted");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "PointsRewardSystem: invalid address");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        authorized[msg.sender] = true;

        emit AuthorizedAdded(msg.sender);
        emit OwnershipTransferred(address(0), msg.sender);
    }


    function awardPoints(
        address recipient,
        uint256 amount,
        string memory reason
    ) external onlyAuthorized whenNotPaused validAddress(recipient) notBlacklisted(recipient) {
        require(amount > 0, "PointsRewardSystem: amount must be greater than zero");
        require(bytes(reason).length > 0, "PointsRewardSystem: reason cannot be empty");

        balanceOf[recipient] += amount;
        totalSupply += amount;

        emit Transfer(address(0), recipient, amount);
        emit PointsAwarded(recipient, amount, reason);
    }


    function deductPoints(
        address account,
        uint256 amount,
        string memory reason
    ) external onlyAuthorized whenNotPaused validAddress(account) notBlacklisted(account) {
        require(amount > 0, "PointsRewardSystem: amount must be greater than zero");
        require(balanceOf[account] >= amount, "PointsRewardSystem: insufficient balance");
        require(bytes(reason).length > 0, "PointsRewardSystem: reason cannot be empty");

        balanceOf[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
        emit PointsDeducted(account, amount, reason);
    }


    function transfer(
        address to,
        uint256 amount
    ) external whenNotPaused validAddress(to) notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        require(amount > 0, "PointsRewardSystem: amount must be greater than zero");
        require(balanceOf[msg.sender] >= amount, "PointsRewardSystem: insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }


    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external whenNotPaused validAddress(from) validAddress(to) notBlacklisted(from) notBlacklisted(to) returns (bool) {
        require(amount > 0, "PointsRewardSystem: amount must be greater than zero");
        require(balanceOf[from] >= amount, "PointsRewardSystem: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "PointsRewardSystem: insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }


    function approve(
        address spender,
        uint256 amount
    ) external whenNotPaused validAddress(spender) notBlacklisted(msg.sender) notBlacklisted(spender) returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function addAuthorized(address account) external onlyOwner validAddress(account) {
        require(!authorized[account], "PointsRewardSystem: account already authorized");

        authorized[account] = true;
        emit AuthorizedAdded(account);
    }


    function removeAuthorized(address account) external onlyOwner validAddress(account) {
        require(authorized[account], "PointsRewardSystem: account not authorized");
        require(account != owner, "PointsRewardSystem: cannot remove owner authorization");

        authorized[account] = false;
        emit AuthorizedRemoved(account);
    }


    function blacklistAccount(address account) external onlyOwner validAddress(account) {
        require(!blacklisted[account], "PointsRewardSystem: account already blacklisted");
        require(account != owner, "PointsRewardSystem: cannot blacklist owner");

        blacklisted[account] = true;
        emit AccountBlacklisted(account);
    }


    function whitelistAccount(address account) external onlyOwner validAddress(account) {
        require(blacklisted[account], "PointsRewardSystem: account not blacklisted");

        blacklisted[account] = false;
        emit AccountWhitelisted(account);
    }


    function pause() external onlyOwner {
        require(!paused, "PointsRewardSystem: contract already paused");

        paused = true;
        emit ContractPaused();
    }


    function unpause() external onlyOwner {
        require(paused, "PointsRewardSystem: contract not paused");

        paused = false;
        emit ContractUnpaused();
    }


    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        require(newOwner != owner, "PointsRewardSystem: new owner is the same as current owner");

        address previousOwner = owner;
        owner = newOwner;
        authorized[newOwner] = true;

        emit AuthorizedAdded(newOwner);
        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function batchAwardPoints(
        address[] memory recipients,
        uint256[] memory amounts,
        string memory reason
    ) external onlyAuthorized whenNotPaused {
        require(recipients.length == amounts.length, "PointsRewardSystem: arrays length mismatch");
        require(recipients.length > 0, "PointsRewardSystem: empty arrays");
        require(bytes(reason).length > 0, "PointsRewardSystem: reason cannot be empty");

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];

            if (recipient == address(0) || blacklisted[recipient] || amount == 0) {
                continue;
            }

            balanceOf[recipient] += amount;
            totalSupply += amount;

            emit Transfer(address(0), recipient, amount);
            emit PointsAwarded(recipient, amount, reason);
        }
    }


    function getAccountInfo(address account) external view returns (
        uint256 balance,
        bool isAuthorized,
        bool isBlacklisted
    ) {
        return (
            balanceOf[account],
            authorized[account],
            blacklisted[account]
        );
    }
}
