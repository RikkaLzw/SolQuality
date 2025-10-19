
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
    address[] public temp1;

    event lock_created(address indexed user, uint256 amount, uint256 unlock_time);
    event tokens_withdrawn(address indexed user, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == o, "Not owner"); _;
    }

    constructor(address _token) {
        t = IERC20(_token); o = msg.sender;
    }

    function create_lock(address user, uint256 amount, uint256 unlock_time) external onlyowner {
        require(amount > 0, "Amount must be > 0");
            require(unlock_time > block.timestamp, "Unlock time must be future");
        require(!locks[user].d, "Lock already exists");

        require(t.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        locks[user] = l({
            a: amount,
            b: unlock_time,
            c: 0,
            d: true
        }); temp1.push(user);

        emit lock_created(user, amount, unlock_time);
    }

    function withdraw_tokens() external {
        l storage x = locks[msg.sender];
        require(x.d, "No lock found");
            require(block.timestamp >= x.b, "Tokens still locked");
        require(x.c < x.a, "All tokens withdrawn");

        uint256 y = x.a - x.c; x.c = x.a;

        require(t.transfer(msg.sender, y), "Transfer failed");

        emit tokens_withdrawn(msg.sender, y);
    }

    function get_lock_info(address user) external view returns (uint256, uint256, uint256, bool) {
        l memory z = locks[user];
        return (z.a, z.b, z.c, z.d);
    }

    function emergency_withdraw(address token_addr, uint256 amt) external onlyowner {
        IERC20(token_addr).transfer(o, amt);
    }

    function get_locked_users_count() external view returns (uint256) {
        return temp1.length;
    }

        function change_owner(address new_owner) external onlyowner {
        require(new_owner != address(0), "Invalid address"); o = new_owner;
    }
}
