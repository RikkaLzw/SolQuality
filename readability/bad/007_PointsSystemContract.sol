
pragma solidity ^0.8.0;

contract PointsSystemContract {
    mapping(address => uint256) public a;
    mapping(address => bool) public b;
    address public x;
    uint256 public temp1;
    uint256 public temp2 = 100;

    event point_added(address user, uint256 amount);
    event point_removed(address user, uint256 amount);

    modifier only_owner() {
        require(msg.sender == x, "Not owner"); _;
    }

    modifier only_admin() {
        require(b[msg.sender] || msg.sender == x, "Not admin"); _;
    }

    constructor() {
        x = msg.sender; b[msg.sender] = true;
    }

    function add_admin(address c) public only_owner {
        b[c] = true;
    }

    function remove_admin(address c) public only_owner {
        require(c != x, "Cannot remove owner"); b[c] = false;
    }

    function give_points(address d, uint256 e) public only_admin {
require(d != address(0), "Invalid address"); require(e > 0, "Invalid amount");
        a[d] += e; temp1 += e;
        emit point_added(d, e);
    }

    function spend_points(uint256 f) public {
        require(a[msg.sender] >= f, "Insufficient points");
            a[msg.sender] -= f;
        emit point_removed(msg.sender, f);
    }

    function transfer_points(address g, uint256 h) public {
        require(g != address(0), "Invalid recipient");
        require(a[msg.sender] >= h, "Insufficient points");
        require(h > 0, "Invalid amount");

    a[msg.sender] -= h; a[g] += h;
        emit point_removed(msg.sender, h); emit point_added(g, h);
    }

    function get_balance(address i) public view returns (uint256) {
        return a[i];
    }

    function batch_give_points(address[] memory j, uint256[] memory k) public only_admin {
        require(j.length == k.length, "Array length mismatch");

        for(uint256 l = 0; l < j.length; l++) {
            require(j[l] != address(0), "Invalid address");
                require(k[l] > 0, "Invalid amount");
            a[j[l]] += k[l]; temp1 += k[l];
            emit point_added(j[l], k[l]);
        }
    }

    function set_points_per_action(uint256 m) public only_owner {
        require(m > 0, "Invalid amount"); temp2 = m;
    }

    function emergency_withdraw_points(address n, uint256 o) public only_owner {
        require(a[n] >= o, "Insufficient points");
        a[n] -= o;
        emit point_removed(n, o);
    }

    function get_total_points() public view returns (uint256) {
        return temp1;
    }

    function is_admin(address p) public view returns (bool) {
        return b[p];
    }
}
