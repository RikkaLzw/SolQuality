
pragma solidity ^0.8.0;

contract PointsSystem {

    event PointsEarned(address indexed user, uint256 amount, bytes32 indexed reason);
    event PointsSpent(address indexed user, uint256 amount, bytes32 indexed reason);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);


    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public admins;
    mapping(bytes32 => bool) public validReasons;

    uint256 public totalSupply;
    uint8 public constant decimals = 18;
    string public constant name = "Points Token";
    string public constant symbol = "PTS";


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Not admin");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be positive");
        _;
    }


    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;


        validReasons[keccak256("PURCHASE")] = true;
        validReasons[keccak256("REFERRAL")] = true;
        validReasons[keccak256("BONUS")] = true;
        validReasons[keccak256("REWARD")] = true;
    }


    function addAdmin(address _admin) external onlyOwner validAddress(_admin) {
        require(!admins[_admin], "Already admin");
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner validAddress(_admin) {
        require(admins[_admin], "Not admin");
        require(_admin != owner, "Cannot remove owner");
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function addValidReason(bytes32 _reason) external onlyAdmin {
        require(!validReasons[_reason], "Reason already exists");
        validReasons[_reason] = true;
    }

    function removeValidReason(bytes32 _reason) external onlyAdmin {
        require(validReasons[_reason], "Reason does not exist");
        validReasons[_reason] = false;
    }


    function earnPoints(
        address _user,
        uint256 _amount,
        bytes32 _reason
    ) external onlyAdmin validAddress(_user) validAmount(_amount) {
        require(validReasons[_reason], "Invalid reason");
        require(_amount <= type(uint256).max - totalSupply, "Overflow");

        balances[_user] += _amount;
        totalSupply += _amount;

        emit PointsEarned(_user, _amount, _reason);
    }

    function spendPoints(
        address _user,
        uint256 _amount,
        bytes32 _reason
    ) external onlyAdmin validAddress(_user) validAmount(_amount) {
        require(validReasons[_reason], "Invalid reason");
        require(balances[_user] >= _amount, "Insufficient balance");

        balances[_user] -= _amount;
        totalSupply -= _amount;

        emit PointsSpent(_user, _amount, _reason);
    }

    function transferPoints(
        address _to,
        uint256 _amount
    ) external validAddress(_to) validAmount(_amount) {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_to != msg.sender, "Cannot transfer to self");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        emit PointsTransferred(msg.sender, _to, _amount);
    }


    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function isAdmin(address _addr) external view returns (bool) {
        return admins[_addr];
    }

    function isValidReason(bytes32 _reason) external view returns (bool) {
        return validReasons[_reason];
    }


    function batchEarnPoints(
        address[] calldata _users,
        uint256[] calldata _amounts,
        bytes32 _reason
    ) external onlyAdmin {
        require(_users.length == _amounts.length, "Array length mismatch");
        require(validReasons[_reason], "Invalid reason");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _users.length; i++) {
            require(_users[i] != address(0), "Invalid address");
            require(_amounts[i] > 0, "Amount must be positive");
            totalAmount += _amounts[i];
        }

        require(totalAmount <= type(uint256).max - totalSupply, "Overflow");

        for (uint256 i = 0; i < _users.length; i++) {
            balances[_users[i]] += _amounts[i];
            emit PointsEarned(_users[i], _amounts[i], _reason);
        }

        totalSupply += totalAmount;
    }


    function pause() external onlyOwner {


    }

    function transferOwnership(address _newOwner) external onlyOwner validAddress(_newOwner) {
        require(_newOwner != owner, "Already owner");


        admins[owner] = false;
        admins[_newOwner] = true;
        owner = _newOwner;
    }
}
