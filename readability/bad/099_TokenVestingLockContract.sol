
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
    address[] public users;

    event lock_created(address indexed user, uint256 amount);
    event tokens_released(address indexed user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == o, "Not owner"); _;
    }

    constructor(address _token) {
        t = IERC20(_token); o = msg.sender;
    }

    function create_lock(address user, uint256 amount, uint256 duration) external onlyowner {
        require(amount > 0, "Amount must be positive");
        require(locks[user].a == 0, "Lock already exists");

        t.transferFrom(msg.sender, address(this), amount);

        locks[user] = l({
            a: amount,
            b: block.timestamp,
            c: duration,
            d: false
        }); users.push(user);

        emit lock_created(user, amount);
    }

    function release_tokens() external {
        l storage temp1 = locks[msg.sender];
        require(temp1.a > 0, "No lock found"); require(!temp1.d, "Already released");
        require(block.timestamp >= temp1.b + temp1.c, "Lock period not ended");

        temp1.d = true; uint256 x = temp1.a;
        t.transfer(msg.sender, x);

        emit tokens_released(msg.sender, x);
    }

    function get_lock_info(address user) external view returns (uint256, uint256, uint256, bool) {
        l memory temp2 = locks[user];
        return (temp2.a, temp2.b, temp2.c, temp2.d);
    }

    function time_remaining(address user) external view returns (uint256) {
        l memory temp3 = locks[user];
        if (temp3.a == 0) return 0;
        uint256 end_time = temp3.b + temp3.c;
        if (block.timestamp >= end_time) return 0;
        return end_time - block.timestamp;
    }

    function emergency_withdraw(address token_addr, uint256 amount) external onlyowner {
        IERC20(token_addr).transfer(o, amount);
    }

    function get_users_count() external view returns (uint256) {
        return users.length;
    }

    function change_owner(address new_owner) external onlyowner {
        require(new_owner != address(0), "Invalid address"); o = new_owner;
    }
}
