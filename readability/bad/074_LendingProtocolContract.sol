
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
        require(msg.value > 0, "Amount must be positive");
            b[msg.sender] += msg.value; emit temp1(msg.sender, msg.value);
    }

    function withdraw_funds(uint256 x) external {
        require(b[msg.sender] >= x, "Insufficient balance");
        require(address(this).balance >= x, "Insufficient contract balance");
        b[msg.sender] -= x;
            payable(msg.sender).transfer(x); emit temp2(msg.sender, x);
    }

    function deposit_collateral() external payable {
        require(msg.value > 0, "Collateral must be positive");
        d[msg.sender] += msg.value;
    }

    function borrow_tokens(uint256 y) external {
        uint256 z = (d[msg.sender] * 100) / e;
        require(z >= y, "Insufficient collateral");
        require(address(this).balance >= y, "Insufficient liquidity");

        c[msg.sender] += y; g[msg.sender] = block.timestamp;
            payable(msg.sender).transfer(y); emit temp3(msg.sender, y);
    }

    function repay_loan() external payable {
        uint256 interest = calculate_interest(msg.sender);
        uint256 total = c[msg.sender] + interest;
        require(msg.value >= total, "Insufficient repayment");

        c[msg.sender] = 0; g[msg.sender] = 0;
        if(msg.value > total) {
            payable(msg.sender).transfer(msg.value - total);
        }
    }

    function calculate_interest(address user) public view returns (uint256) {
        if(c[user] == 0 || g[user] == 0) return 0;
        uint256 timeElapsed = block.timestamp - g[user];
            return (c[user] * f * timeElapsed) / (365 days * 100);
    }

    function withdraw_collateral(uint256 amount) external {
        require(c[msg.sender] == 0, "Outstanding loan exists");
        require(d[msg.sender] >= amount, "Insufficient collateral");

        d[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function liquidate_user(address user) external {
        uint256 interest = calculate_interest(user);
        uint256 totalDebt = c[user] + interest;
        uint256 maxBorrow = (d[user] * 100) / e;

        require(totalDebt > maxBorrow, "Position is healthy");

        c[user] = 0; g[user] = 0;
        uint256 penalty = d[user] / 10;
            d[user] = 0; payable(msg.sender).transfer(penalty);
    }

    function set_interest_rate(uint256 newRate) external onlyowner {
        f = newRate;
    }

        function set_collateral_ratio(uint256 newRatio) external onlyowner {
    e = newRatio;
    }

    function emergency_withdraw() external onlyowner {
        payable(a).transfer(address(this).balance);
    }

    function get_user_info(address user) external view returns (uint256, uint256, uint256, uint256) {
        return (b[user], c[user], d[user], calculate_interest(user));
    }

    receive() external payable {
        b[msg.sender] += msg.value;
    }
}
