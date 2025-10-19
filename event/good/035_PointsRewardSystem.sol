
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
    uint256 public maxSupply;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event PointsAwarded(address indexed recipient, uint256 indexed amount, string reason);
    event PointsBurned(address indexed account, uint256 indexed amount, string reason);
    event MinterAuthorized(address indexed minter, bool indexed status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractPaused(bool indexed pauseStatus);
    event MaxSupplyUpdated(uint256 indexed oldMaxSupply, uint256 indexed newMaxSupply);


    modifier onlyOwner() {
        require(msg.sender == owner, "PointsRewardSystem: caller is not the owner");
        _;
    }

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner, "PointsRewardSystem: caller is not authorized to mint");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "PointsRewardSystem: contract is paused");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "PointsRewardSystem: invalid zero address");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _maxSupply
    ) {
        require(bytes(_name).length > 0, "PointsRewardSystem: name cannot be empty");
        require(bytes(_symbol).length > 0, "PointsRewardSystem: symbol cannot be empty");
        require(_maxSupply > 0, "PointsRewardSystem: max supply must be greater than zero");

        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        maxSupply = _maxSupply;
        paused = false;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transfer(address to, uint256 amount)
        external
        whenNotPaused
        validAddress(to)
        returns (bool)
    {
        require(balanceOf[msg.sender] >= amount, "PointsRewardSystem: insufficient balance for transfer");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external
        whenNotPaused
        validAddress(spender)
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        validAddress(from)
        validAddress(to)
        returns (bool)
    {
        require(balanceOf[from] >= amount, "PointsRewardSystem: insufficient balance for transfer");
        require(allowance[from][msg.sender] >= amount, "PointsRewardSystem: insufficient allowance for transfer");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function awardPoints(address recipient, uint256 amount, string calldata reason)
        external
        onlyAuthorizedMinter
        whenNotPaused
        validAddress(recipient)
    {
        require(amount > 0, "PointsRewardSystem: award amount must be greater than zero");
        require(bytes(reason).length > 0, "PointsRewardSystem: award reason cannot be empty");

        if (totalSupply + amount > maxSupply) {
            revert("PointsRewardSystem: awarding points would exceed maximum supply");
        }

        totalSupply += amount;
        balanceOf[recipient] += amount;

        emit Transfer(address(0), recipient, amount);
        emit PointsAwarded(recipient, amount, reason);
    }

    function burnPoints(uint256 amount, string calldata reason)
        external
        whenNotPaused
    {
        require(amount > 0, "PointsRewardSystem: burn amount must be greater than zero");
        require(bytes(reason).length > 0, "PointsRewardSystem: burn reason cannot be empty");
        require(balanceOf[msg.sender] >= amount, "PointsRewardSystem: insufficient balance to burn");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        emit PointsBurned(msg.sender, amount, reason);
    }

    function burnPointsFrom(address account, uint256 amount, string calldata reason)
        external
        onlyOwner
        whenNotPaused
        validAddress(account)
    {
        require(amount > 0, "PointsRewardSystem: burn amount must be greater than zero");
        require(bytes(reason).length > 0, "PointsRewardSystem: burn reason cannot be empty");
        require(balanceOf[account] >= amount, "PointsRewardSystem: insufficient balance to burn from account");

        balanceOf[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
        emit PointsBurned(account, amount, reason);
    }

    function authorizeMinter(address minter, bool status)
        external
        onlyOwner
        validAddress(minter)
    {
        require(minter != owner, "PointsRewardSystem: owner is always authorized");

        authorizedMinters[minter] = status;
        emit MinterAuthorized(minter, status);
    }

    function setPaused(bool _paused) external onlyOwner {
        require(paused != _paused, "PointsRewardSystem: pause status is already set to this value");

        paused = _paused;
        emit ContractPaused(_paused);
    }

    function updateMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply >= totalSupply, "PointsRewardSystem: new max supply cannot be less than current total supply");
        require(newMaxSupply != maxSupply, "PointsRewardSystem: new max supply must be different from current max supply");

        uint256 oldMaxSupply = maxSupply;
        maxSupply = newMaxSupply;

        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
        validAddress(newOwner)
    {
        require(newOwner != owner, "PointsRewardSystem: new owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function getAccountInfo(address account)
        external
        view
        validAddress(account)
        returns (uint256 balance, bool isMinter)
    {
        return (balanceOf[account], authorizedMinters[account]);
    }

    function getContractInfo()
        external
        view
        returns (
            string memory contractName,
            string memory contractSymbol,
            uint8 contractDecimals,
            uint256 currentSupply,
            uint256 maximumSupply,
            bool isPaused,
            address contractOwner
        )
    {
        return (name, symbol, decimals, totalSupply, maxSupply, paused, owner);
    }
}
