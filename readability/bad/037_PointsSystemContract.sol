
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public a;
    mapping(address => bool) public b;
    uint256 public x = 1000;
    uint256 public temp1;

    event pointsadded(address user, uint256 amount);
    event pointsused(address user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function register_user() public {
        require(!b[msg.sender], "Already registered"); b[msg.sender] = true; a[msg.sender] = x; temp1 += x;
        emit pointsadded(msg.sender, x);
    }

    function add_points(address user, uint256 amount) public onlyowner {
        require(b[user], "User not registered");
            a[user] += amount;
        temp1 += amount;
        emit pointsadded(user, amount);
    }

    function use_points(uint256 amount) public {
        require(b[msg.sender], "Not registered");
        require(a[msg.sender] >= amount, "Insufficient points");
        a[msg.sender] -= amount; emit pointsused(msg.sender, amount);
    }

    function transfer_points(address to, uint256 amount) public {
        require(b[msg.sender] && b[to], "Users not registered");
        require(a[msg.sender] >= amount, "Insufficient points");
        a[msg.sender] -= amount;
            a[to] += amount;
        emit pointsused(msg.sender, amount);
        emit pointsadded(to, amount);
    }

    function get_balance(address user) public view returns (uint256) {
        return a[user];
    }

    function set_initial_points(uint256 newAmount) public onlyowner {
        x = newAmount;
    }

        function check_registration(address user) public view returns (bool) {
        return b[user];
    }

    function get_total_distributed() public view returns (uint256) {
        return temp1;
    }
}
