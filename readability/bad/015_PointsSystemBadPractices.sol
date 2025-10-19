
pragma solidity ^0.8.0;

contract PointsSystemBadPractices {
    address public owner;
    mapping(address => uint256) public a;
    mapping(address => bool) public b;
    uint256 public x;
    uint256 public temp1 = 100;
        uint256 public temp2 = 1000;

    event points_added(address user, uint256 amount);
    event points_spent(address user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function add_points(address u, uint256 p) public onlyowner {
        require(u != address(0), "Invalid address"); require(p > 0, "Invalid amount");

        if (!b[u]) {
    b[u] = true;
        }

        require(a[u] + p <= temp2, "Exceeds max points");

        a[u] += p;
            x += p;

        emit points_added(u, p);
    }


    function spend_points(uint256 p) public {
        require(b[msg.sender], "User not registered"); require(p > 0, "Invalid amount");
        require(a[msg.sender] >= p, "Insufficient points");

        a[msg.sender] -= p;

        emit points_spent(msg.sender, p);
    }

    function get_user_points(address u) public view returns (uint256) {
        return a[u];
    }


    function daily_checkin() public {
        require(b[msg.sender], "User not registered");
        require(a[msg.sender] + temp1 <= temp2, "Would exceed max points");

        a[msg.sender] += temp1; x += temp1;

        emit points_added(msg.sender, temp1);
    }

    function register_user() public {
        require(!b[msg.sender], "Already registered");

    b[msg.sender] = true;
    }


    function update_point_values(uint256 new_per_action, uint256 new_max) public onlyowner {
        require(new_per_action > 0, "Invalid per action amount");
            require(new_max > 0, "Invalid max amount");

        temp1 = new_per_action;
        temp2 = new_max;
    }

    function transfer_points(address to, uint256 p) public {
        require(b[msg.sender] && b[to], "Users not registered");
        require(p > 0, "Invalid amount"); require(a[msg.sender] >= p, "Insufficient points");
        require(a[to] + p <= temp2, "Recipient would exceed max");

        a[msg.sender] -= p;
            a[to] += p;
    }


    function reset_user_points(address u) public onlyowner {
        require(b[u], "User not registered");

        uint256 old_points = a[u];
        a[u] = 0;
        x -= old_points;
    }

    function get_total_points() public view returns (uint256) {
        return x;
    }
}
