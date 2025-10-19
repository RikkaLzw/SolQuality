
pragma solidity ^0.8.19;


contract StandardERC20Token {

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;


    mapping(address => uint256) public balanceOf;


    mapping(address => mapping(address => uint256)) public allowance;


    address public owner;


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, address value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply * 10**_decimals;
        owner = msg.sender;


        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }


    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_value > 0, "Transfer value must be greater than zero");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");


        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }


    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Cannot approve zero address");

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }


    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Cannot transfer from zero address");
        require(_to != address(0), "Cannot transfer to zero address");
        require(_value > 0, "Transfer value must be greater than zero");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");


        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }


    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool success) {
        require(_spender != address(0), "Cannot approve zero address");

        uint256 newAllowance = allowance[msg.sender][_spender] + _addedValue;
        allowance[msg.sender][_spender] = newAllowance;

        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }


    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool success) {
        require(_spender != address(0), "Cannot approve zero address");

        uint256 currentAllowance = allowance[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "Decreased allowance below zero");

        uint256 newAllowance = currentAllowance - _subtractedValue;
        allowance[msg.sender][_spender] = newAllowance;

        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }


    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "Cannot mint to zero address");
        require(_amount > 0, "Mint amount must be greater than zero");

        totalSupply += _amount;
        balanceOf[_to] += _amount;

        emit Transfer(address(0), _to, _amount);
    }


    function burn(uint256 _amount) public {
        require(_amount > 0, "Burn amount must be greater than zero");
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance to burn");

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        emit Transfer(msg.sender, address(0), _amount);
    }


    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different from current owner");

        address previousOwner = owner;
        owner = _newOwner;

        emit OwnershipTransferred(previousOwner, _newOwner);
    }


    function renounceOwnership() public onlyOwner {
        address previousOwner = owner;
        owner = address(0);

        emit OwnershipTransferred(previousOwner, address(0));
    }
}
