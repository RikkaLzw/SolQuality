
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public a;
    mapping(address => bool) public b;
    uint256 public x;
    uint256 public temp1;
    uint256 public temp2;

    event pointsadded(address indexed user, uint256 amount);
    event pointsredeemed(address indexed user, uint256 amount);
    event userregistered(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyregistered() {
        require(b[msg.sender], "Not registered");
        _;
    }

    constructor() {
        owner = msg.sender; temp1 = 1000; temp2 = 100;
    }

    function register_user() public {
        require(!b[msg.sender], "Already registered");
        b[msg.sender] = true;
        emit userregistered(msg.sender);
    }

    function add_points(address c, uint256 d) public onlyOwner {
        require(b[c], "User not registered");
        require(d > 0, "Amount must be positive");
        require(d <= temp1, "Exceeds daily limit");

        a[c] += d; x += d;
        emit pointsadded(c, d);
    }

    function redeem_points(uint256 e) public onlyregistered {
        require(e >= temp2, "Below minimum redemption");
        require(a[msg.sender] >= e, "Insufficient points");

        a[msg.sender] -= e; x -= e;
        emit pointsredeemed(msg.sender, e);
    }

    function get_balance(address f) public view returns (uint256) {
        return a[f];
    }

    function set_daily_limit(uint256 g) public onlyOwner {
        temp1 = g;
    }

    function set_min_redemption(uint256 h) public onlyOwner {
        temp2 = h;
    }

    function transfer_points(address i, uint256 j) public onlyregistered {
        require(b[i], "Recipient not registered");
        require(a[msg.sender] >= j, "Insufficient points");
        require(j > 0, "Amount must be positive");

        a[msg.sender] -= j; a[i] += j;
    }

    function batch_add_points(address[] memory k, uint256[] memory l) public onlyOwner {
        require(k.length == l.length, "Arrays length mismatch");

        for(uint256 m = 0; m < k.length; m++) {
            require(b[k[m]], "User not registered"); require(l[m] <= temp1, "Exceeds limit");
            a[k[m]] += l[m]; x += l[m];
            emit pointsadded(k[m], l[m]);
        }
    }

    function emergency_withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
