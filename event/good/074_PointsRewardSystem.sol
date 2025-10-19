
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => bool) public authorizedMinters;

    bool public paused;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed recipient, uint256 indexed amount, string reason);
    event PointsRedeemed(address indexed user, uint256 indexed amount, string item);
    event MinterAuthorized(address indexed minter, bool indexed status);
    event ContractPaused(bool indexed status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    error InsufficientBalance(uint256 requested, uint256 available);
    error InsufficientAllowance(uint256 requested, uint256 available);
    error UnauthorizedMinter(address caller);
    error ContractIsPaused();
    error OnlyOwnerAllowed(address caller);
    error InvalidAddress();
    error InvalidAmount();
    error SelfTransferNotAllowed();


    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwnerAllowed(msg.sender);
        }
        _;
    }

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender] && msg.sender != owner) {
            revert UnauthorizedMinter(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert ContractIsPaused();
        }
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    modifier validAmount(uint256 _amount) {
        if (_amount == 0) {
            revert InvalidAmount();
        }
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


    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address _owner, address spender) public view returns (uint256) {
        return allowances[_owner][spender];
    }

    function transfer(address to, uint256 amount)
        public
        whenNotPaused
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        if (msg.sender == to) {
            revert SelfTransferNotAllowed();
        }

        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        whenNotPaused
        validAddress(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        whenNotPaused
        validAddress(from)
        validAddress(to)
        validAmount(amount)
        returns (bool)
    {
        if (from == to) {
            revert SelfTransferNotAllowed();
        }

        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(amount, currentAllowance);
        }

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);

        return true;
    }


    function awardPoints(address recipient, uint256 amount, string memory reason)
        public
        onlyAuthorizedMinter
        whenNotPaused
        validAddress(recipient)
        validAmount(amount)
    {
        _mint(recipient, amount);
        emit PointsAwarded(recipient, amount, reason);
    }

    function redeemPoints(uint256 amount, string memory item)
        public
        whenNotPaused
        validAmount(amount)
    {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        _burn(msg.sender, amount);
        emit PointsRedeemed(msg.sender, amount, item);
    }

    function batchAwardPoints(
        address[] memory recipients,
        uint256[] memory amounts,
        string memory reason
    )
        public
        onlyAuthorizedMinter
        whenNotPaused
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays not allowed");

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) {
                revert InvalidAddress();
            }
            if (amounts[i] == 0) {
                revert InvalidAmount();
            }

            _mint(recipients[i], amounts[i]);
            emit PointsAwarded(recipients[i], amounts[i], reason);
        }
    }


    function authorizeMinter(address minter, bool status)
        public
        onlyOwner
        validAddress(minter)
    {
        authorizedMinters[minter] = status;
        emit MinterAuthorized(minter, status);
    }

    function pauseContract(bool _paused) public onlyOwner {
        paused = _paused;
        emit ContractPaused(_paused);
    }

    function transferOwnership(address newOwner)
        public
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
        if (balances[from] < amount) {
            revert InsufficientBalance(amount, balances[from]);
        }

        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        totalSupply -= amount;
        balances[from] -= amount;

        emit Transfer(from, address(0), amount);
    }

    function _approve(address _owner, address spender, uint256 amount) internal {
        allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }


    function isAuthorizedMinter(address account) public view returns (bool) {
        return authorizedMinters[account];
    }

    function getContractInfo() public view returns (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        bool _paused,
        address _owner
    ) {
        return (name, symbol, decimals, totalSupply, paused, owner);
    }
}
