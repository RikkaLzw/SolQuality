
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public authorizedMinters;

    bool public paused;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed recipient, uint256 amount, string indexed reason);
    event PointsRedeemed(address indexed user, uint256 amount, string indexed item);
    event MinterAuthorized(address indexed minter, bool authorized);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractPaused(bool paused);


    error InsufficientBalance(uint256 requested, uint256 available);
    error InsufficientAllowance(uint256 requested, uint256 available);
    error UnauthorizedMinter(address caller);
    error ContractPaused();
    error InvalidAddress();
    error InvalidAmount();
    error OnlyOwner();
    error ZeroAmount();


    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender] && msg.sender != owner) {
            revert UnauthorizedMinter(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    modifier validAmount(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
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
        authorizedMinters[msg.sender] = true;

        emit MinterAuthorized(msg.sender, true);
        emit OwnershipTransferred(address(0), msg.sender);
    }


    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        validAddress(from)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(amount, currentAllowance);
        }

        allowance[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);

        return true;
    }

    function approve(address spender, uint256 amount)
        external
        validAddress(spender)
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function awardPoints(address recipient, uint256 amount, string calldata reason)
        external
        onlyAuthorizedMinter
        whenNotPaused
        validAddress(recipient)
        validAmount(amount)
    {
        balanceOf[recipient] += amount;
        totalSupply += amount;

        emit Transfer(address(0), recipient, amount);
        emit PointsAwarded(recipient, amount, reason);
    }

    function redeemPoints(uint256 amount, string calldata item)
        external
        whenNotPaused
        validAmount(amount)
    {
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(amount, balanceOf[msg.sender]);
        }

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        emit PointsRedeemed(msg.sender, amount, item);
    }

    function batchAwardPoints(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string calldata reason
    )
        external
        onlyAuthorizedMinter
        whenNotPaused
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays not allowed");

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidAddress();
            if (amounts[i] == 0) revert ZeroAmount();

            balanceOf[recipients[i]] += amounts[i];
            totalSupply += amounts[i];

            emit Transfer(address(0), recipients[i], amounts[i]);
            emit PointsAwarded(recipients[i], amounts[i], reason);
        }
    }


    function authorizeMinter(address minter, bool authorized)
        external
        onlyOwner
        validAddress(minter)
    {
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPaused(_paused);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
        validAddress(newOwner)
    {
        address previousOwner = owner;
        owner = newOwner;
        authorizedMinters[newOwner] = true;

        emit OwnershipTransferred(previousOwner, newOwner);
        emit MinterAuthorized(newOwner, true);
    }


    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) {
            revert InsufficientBalance(amount, balanceOf[from]);
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }


    function getBalance(address account) external view returns (uint256) {
        return balanceOf[account];
    }

    function isMinterAuthorized(address minter) external view returns (bool) {
        return authorizedMinters[minter];
    }

    function getAllowance(address _owner, address spender) external view returns (uint256) {
        return allowance[_owner][spender];
    }
}
