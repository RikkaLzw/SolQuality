
pragma solidity ^0.8.0;

contract ERC20TokenWithBadPractices {

    uint256 public decimals = 18;
    uint256 public totalSupply;


    string public name = "BadPracticeToken";
    string public symbol = "BPT";

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;


    bytes public contractIdentifier = "ERC20_TOKEN_CONTRACT_ID_12345";


    uint256 public isPaused = 0;
    uint256 public isInitialized = 0;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(isPaused == 0, "Contract is paused");
        _;
    }

    constructor(uint256 _initialSupply) {

        totalSupply = uint256(_initialSupply) * 10**uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
        isInitialized = uint256(1);

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        require(_spender != address(0), "Approve to zero address");

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_from != address(0), "Transfer from zero address");
        require(_to != address(0), "Transfer to zero address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function mint(address _to, uint256 _amount) public onlyOwner whenNotPaused returns (bool) {
        require(_to != address(0), "Mint to zero address");


        totalSupply += uint256(_amount);
        balanceOf[_to] += uint256(_amount);

        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function burn(uint256 _amount) public whenNotPaused returns (bool) {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance to burn");

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        emit Transfer(msg.sender, address(0), _amount);
        return true;
    }

    function pause() public onlyOwner {
        isPaused = uint256(1);
    }

    function unpause() public onlyOwner {
        isPaused = uint256(0);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");

        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }


    function setDecimals(uint256 _newDecimals) public onlyOwner {
        require(_newDecimals <= 18, "Decimals too high");
        decimals = _newDecimals;
    }


    function updateContractIdentifier(bytes memory _newIdentifier) public onlyOwner {
        contractIdentifier = _newIdentifier;
    }


    function checkPauseStatus() public view returns (uint256) {
        return isPaused;
    }


    function getDecimalsAsUint256() public view returns (uint256) {
        return uint256(decimals);
    }
}
