
pragma solidity ^0.8.0;

contract PointsSystem {

    mapping(address => uint256) private balances;
    mapping(address => bool) private authorized;
    address private owner;
    uint256 private totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;


    event PointsAwarded(address indexed to, uint256 amount);
    event PointsDeducted(address indexed from, uint256 amount);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event AuthorizedAdded(address indexed account);
    event AuthorizedRemoved(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }

    modifier sufficientBalance(address account, uint256 amount) {
        require(balances[account] >= amount, "Insufficient balance");
        _;
    }


    constructor(string memory _name, string memory _symbol) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = 18;
        authorized[msg.sender] = true;
    }


    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function isAuthorized(address account) public view returns (bool) {
        return authorized[account];
    }


    function transferOwnership(address newOwner) public onlyOwner validAddress(newOwner) {
        address previousOwner = owner;
        owner = newOwner;
        authorized[newOwner] = true;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function addAuthorized(address account) public onlyOwner validAddress(account) {
        authorized[account] = true;
        emit AuthorizedAdded(account);
    }

    function removeAuthorized(address account) public onlyOwner validAddress(account) {
        require(account != owner, "Cannot remove owner");
        authorized[account] = false;
        emit AuthorizedRemoved(account);
    }


    function awardPoints(address to, uint256 amount) public onlyAuthorized validAddress(to) {
        require(amount > 0, "Amount must be positive");

        balances[to] += amount;
        totalSupply += amount;

        emit PointsAwarded(to, amount);
    }

    function deductPoints(address from, uint256 amount) public onlyAuthorized validAddress(from) sufficientBalance(from, amount) {
        require(amount > 0, "Amount must be positive");

        balances[from] -= amount;
        totalSupply -= amount;

        emit PointsDeducted(from, amount);
    }


    function transfer(address to, uint256 amount) public validAddress(to) sufficientBalance(msg.sender, amount) returns (bool) {
        require(amount > 0, "Amount must be positive");
        require(to != msg.sender, "Cannot transfer to self");

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit PointsTransferred(msg.sender, to, amount);
        return true;
    }


    function _validateTransfer(address from, address to, uint256 amount) internal view returns (bool) {
        return from != address(0) &&
               to != address(0) &&
               amount > 0 &&
               balances[from] >= amount;
    }

    function _executeTransfer(address from, address to, uint256 amount) internal {
        balances[from] -= amount;
        balances[to] += amount;
        emit PointsTransferred(from, to, amount);
    }


    function batchAwardPoints(address[] memory recipients, uint256[] memory amounts) public onlyAuthorized {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < recipients.length; i++) {
            awardPoints(recipients[i], amounts[i]);
        }
    }

    function batchTransfer(address[] memory recipients, uint256[] memory amounts) public returns (bool) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 50, "Batch size too large");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(balances[msg.sender] >= totalAmount, "Insufficient total balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(_validateTransfer(msg.sender, recipients[i], amounts[i]), "Invalid transfer");
            _executeTransfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }
}
