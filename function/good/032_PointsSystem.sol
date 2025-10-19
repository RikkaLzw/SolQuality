
pragma solidity ^0.8.0;

contract PointsSystem {
    string public name = "Points System";
    string public symbol = "PTS";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public owner;
    bool public paused;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => bool) public authorized;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed to, uint256 amount, string reason);
    event PointsDeducted(address indexed from, uint256 amount, string reason);
    event AuthorizationChanged(address indexed account, bool authorized);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused();
    event Unpaused();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address ownerAddr, address spender) public view returns (uint256) {
        return allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) public whenNotPaused validAddress(spender) returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public whenNotPaused returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);

        return true;
    }

    function awardPoints(address to, uint256 amount, string memory reason)
        public
        onlyAuthorized
        whenNotPaused
        validAddress(to)
        returns (bool)
    {
        require(amount > 0, "Amount must be positive");

        balances[to] += amount;
        totalSupply += amount;

        emit Transfer(address(0), to, amount);
        emit PointsAwarded(to, amount, reason);

        return true;
    }

    function deductPoints(address from, uint256 amount, string memory reason)
        public
        onlyAuthorized
        whenNotPaused
        validAddress(from)
        returns (bool)
    {
        require(amount > 0, "Amount must be positive");
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
        emit PointsDeducted(from, amount, reason);

        return true;
    }

    function batchAwardPoints(address[] memory recipients, uint256[] memory amounts)
        public
        onlyAuthorized
        whenNotPaused
        returns (bool)
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 100, "Too many recipients");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            require(amounts[i] > 0, "Amount must be positive");

            balances[recipients[i]] += amounts[i];
            totalSupply += amounts[i];

            emit Transfer(address(0), recipients[i], amounts[i]);
            emit PointsAwarded(recipients[i], amounts[i], "Batch award");
        }

        return true;
    }

    function setAuthorization(address account, bool isAuthorized)
        public
        onlyOwner
        validAddress(account)
        returns (bool)
    {
        require(account != owner, "Cannot change owner authorization");

        authorized[account] = isAuthorized;
        emit AuthorizationChanged(account, isAuthorized);

        return true;
    }

    function transferOwnership(address newOwner) public onlyOwner validAddress(newOwner) returns (bool) {
        require(newOwner != owner, "Already owner");

        address previousOwner = owner;
        owner = newOwner;
        authorized[newOwner] = true;

        emit OwnershipTransferred(previousOwner, newOwner);

        return true;
    }

    function pause() public onlyOwner returns (bool) {
        require(!paused, "Already paused");

        paused = true;
        emit Paused();

        return true;
    }

    function unpause() public onlyOwner returns (bool) {
        require(paused, "Not paused");

        paused = false;
        emit Unpaused();

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal validAddress(to) {
        require(from != address(0), "Transfer from zero address");
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddr, address spender, uint256 amount) internal {
        allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }
}
