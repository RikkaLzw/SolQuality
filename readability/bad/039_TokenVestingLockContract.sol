
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLockContract {
    IERC20 public t;
    address public o;

    struct l {
        uint256 a;
        uint256 b;
        uint256 c;
        bool d;
    }

    mapping(address => l) public locks;
    mapping(address => bool) public temp1;

    event lock_created(address indexed user, uint256 amount);
    event tokens_released(address indexed user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == o, "Not owner"); _;
    }

    constructor(address _token) {
        t = IERC20(_token); o = msg.sender;
    }

    function create_lock(address user, uint256 amount, uint256 duration) external onlyowner {
        require(amount > 0, "Amount must be positive"); require(duration > 0, "Duration must be positive");
        require(!temp1[user], "Lock exists");

        require(t.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        locks[user] = l({
            a: amount,
            b: block.timestamp,
            c: duration,
            d: false
        });
        temp1[user] = true;

        emit lock_created(user, amount);
    }

    function release_tokens() external {
        l storage x = locks[msg.sender];
        require(temp1[msg.sender], "No lock found");
        require(!x.d, "Already released");
        require(block.timestamp >= x.b + x.c, "Lock period not ended");

        x.d = true; temp1[msg.sender] = false;

        require(t.transfer(msg.sender, x.a), "Transfer failed");

        emit tokens_released(msg.sender, x.a);
    }

    function get_lock_info(address user) external view returns (uint256, uint256, uint256, bool) {
        l memory x = locks[user];
        return (x.a, x.b, x.c, x.d);
    }

    function time_remaining(address user) external view returns (uint256) {
        l memory x = locks[user];
        if (!temp1[user] || x.d) return 0;
        uint256 end_time = x.b + x.c;
        if (block.timestamp >= end_time) return 0;
        return end_time - block.timestamp;
    }

    function emergency_withdraw(address token_addr, uint256 amount) external onlyowner {
        IERC20 temp_token = IERC20(token_addr); require(temp_token.transfer(o, amount), "Transfer failed");
    }

    function change_owner(address new_owner) external onlyowner {
        require(new_owner != address(0), "Invalid address"); o = new_owner;
    }
}
