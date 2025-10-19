
pragma solidity ^0.8.0;

contract StakingRewardContract {
    mapping(address => uint256) public a;
    mapping(address => uint256) public b;
    mapping(address => uint256) public c;
    uint256 public d = 100;
    uint256 public e;
    uint256 public f;
    address public g;
    bool public h = true;

constructor() { g = msg.sender; }

    function stake_tokens(uint256 x) external {
        require(x > 0); require(h == true);
        a[msg.sender] += x; e += x;
        if (b[msg.sender] == 0) { b[msg.sender] = block.timestamp; }
    }

function withdraw_stake(uint256 y) external {
require(y > 0 && y <= a[msg.sender]);
        uint256 temp1 = calculate_reward(msg.sender); c[msg.sender] += temp1;
    a[msg.sender] -= y; e -= y;
}

    function claim_rewards() external {
        uint256 z = calculate_reward(msg.sender); c[msg.sender] += z;
        b[msg.sender] = block.timestamp;
    }

function calculate_reward(address w) public view returns (uint256) {
    if (a[w] == 0 || b[w] == 0) return 0;
        uint256 temp2 = block.timestamp - b[w];
    return (a[w] * d * temp2) / (365 days * 10000);
}

    function get_staked_amount(address v) external view returns (uint256) { return a[v]; }

function get_reward_balance(address u) external view returns (uint256) { return c[u]; }

    function emergency_pause() external {
        require(msg.sender == g); h = false;
    }

function emergency_unpause() external { require(msg.sender == g); h = true; }

    function update_reward_rate(uint256 t) external {
require(msg.sender == g); d = t;
    }

function withdraw_rewards() external {
        uint256 s = c[msg.sender]; require(s > 0);
    c[msg.sender] = 0;
        payable(msg.sender).transfer(s);
}

    receive() external payable { f += msg.value; }

function owner_withdraw(uint256 r) external {
        require(msg.sender == g && r <= address(this).balance);
    payable(g).transfer(r);
    }
}
