
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract InefficientERC20Token is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _decimals;

    string private _contractId;
    bytes private _metadata;
    uint256 private _isPaused;
    uint256 private _isInitialized;

    address private _owner;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_ * 10**_decimals;
        _balances[msg.sender] = _totalSupply;
        _owner = msg.sender;

        _contractId = "ERC20_TOKEN_V1";
        _metadata = abi.encodePacked("token_metadata_", block.timestamp);
        _isPaused = 0;
        _isInitialized = 1;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(_isPaused == 0, "Token is paused");
        require(_isInitialized == 1, "Token not initialized");

        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(_isPaused == 0, "Token is paused");

        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(_isPaused == 0, "Token is paused");
        require(_isInitialized == 1, "Token not initialized");

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }


    function pause() external {
        require(msg.sender == _owner, "Only owner can pause");
        _isPaused = 1;
    }

    function unpause() external {
        require(msg.sender == _owner, "Only owner can unpause");
        _isPaused = 0;
    }

    function getContractId() external view returns (string memory) {
        return _contractId;
    }

    function getMetadata() external view returns (bytes memory) {
        return _metadata;
    }

    function isPaused() external view returns (uint256) {
        return _isPaused;
    }

    function updateMetadata(bytes calldata newMetadata) external {
        require(msg.sender == _owner, "Only owner can update metadata");

        _metadata = bytes(newMetadata);
    }

    function getDecimalsAsUint8() external view returns (uint8) {

        return uint8(uint256(_decimals));
    }

    function checkInitialized() external view returns (uint256) {

        return uint256(_isInitialized);
    }
}
