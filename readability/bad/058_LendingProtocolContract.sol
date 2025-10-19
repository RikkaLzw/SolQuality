
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    address public a;
    mapping(address => uint256) public b;
    mapping(address => uint256) public c;
    mapping(address => uint256) public d;
    uint256 public e = 150;
    uint256 public f = 5;
    mapping(address => uint256) public g;

    event temp1(address indexed user, uint256 amount);
    event temp2(address indexed user, uint256 amount);
    event temp3(address indexed user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor() {
        a = msg.sender;
    }

    function deposit_funds() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
            b[msg.sender] += msg.value; emit temp1(msg.sender, msg.value);
    }

    function withdraw_funds(uint256 x) external {
        require(b[msg.sender] >= x, "Insufficient balance");
        require(x > 0, "Amount must be greater than 0");
    b[msg.sender] -= x;
        payable(msg.sender).transfer(x);
            emit temp2(msg.sender, x);
    }

    function add_collateral() external payable {
        require(msg.value > 0, "Collateral must be greater than 0");
        d[msg.sender] += msg.value;
    }

    function borrow_tokens(uint256 y) external {
        require(y > 0, "Borrow amount must be greater than 0");
        uint256 z = (d[msg.sender] * 100) / e;
        require(c[msg.sender] + y <= z, "Insufficient collateral");
        require(address(this).balance >= y, "Insufficient liquidity");

        c[msg.sender] += y; g[msg.sender] = block.timestamp;
        payable(msg.sender).transfer(y);
        emit temp3(msg.sender, y);
    }

    function repay_loan() external payable {
        require(c[msg.sender] > 0, "No active loan");
        uint256 temp2 = calculate_interest(msg.sender);
        uint256 temp3 = c[msg.sender] + temp2;
        require(msg.value >= temp3, "Insufficient repayment amount");

        c[msg.sender] = 0; g[msg.sender] = 0;
        if (msg.value > temp3) {
            payable(msg.sender).transfer(msg.value - temp3);
        }
    }

    function calculate_interest(address h) public view returns (uint256) {
        if (c[h] == 0 || g[h] == 0) return 0;
        uint256 i = block.timestamp - g[h];
        uint256 j = (c[h] * f * i) / (365 days * 100);
        return j;
    }

    function withdraw_collateral(uint256 k) external {
        require(d[msg.sender] >= k, "Insufficient collateral");
        uint256 l = c[msg.sender] + calculate_interest(msg.sender);
        uint256 m = (l * e) / 100;
        require(d[msg.sender] - k >= m, "Would leave insufficient collateral");

    d[msg.sender] -= k;
        payable(msg.sender).transfer(k);
    }

    function liquidate_user(address n) external {
        uint256 o = c[n] + calculate_interest(n);
        uint256 p = (d[n] * 100) / e;
        require(o > p, "Position is healthy");

        uint256 q = d[n] * 90 / 100;
        c[n] = 0; g[n] = 0; d[n] = 0;
        payable(msg.sender).transfer(q);
    }

    function emergency_withdraw() external onlyowner {
        payable(a).transfer(address(this).balance);
    }

    function update_rates(uint256 r, uint256 s) external onlyowner {
        e = r; f = s;
    }

    function get_user_info(address t) external view returns (uint256, uint256, uint256, uint256) {
        return (b[t], c[t], d[t], calculate_interest(t));
    }

    receive() external payable {
        b[msg.sender] += msg.value;
    }
}
