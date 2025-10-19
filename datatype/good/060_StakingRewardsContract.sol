
pragma solidity ^0.8.0;

contract StakingRewardsContract {

    address public owner;
    address public rewardToken;
    address public stakingToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;
    uint256 public constant PRECISION = 1e18;

    bool public paused;


    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public authorized;


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event Paused();
    event Unpaused();


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        require(_rewardRate > 0, "Invalid reward rate");

        owner = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
        authorized[msg.sender] = true;
    }


    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * PRECISION) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / PRECISION + rewards[account];
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }


    function stake(uint256 amount) external notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        totalSupply += amount;
        balances[msg.sender] += amount;


        (bool success, bytes memory data) = stakingToken.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        totalSupply -= amount;
        balances[msg.sender] -= amount;


        (bool success, bytes memory data) = stakingToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public notPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;


            (bool success, bytes memory data) = rewardToken.call(
                abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "Reward transfer failed");

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }


    function setRewardRate(uint256 _rewardRate) external onlyAuthorized updateReward(address(0)) {
        require(_rewardRate > 0, "Invalid reward rate");
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function addAuthorized(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        authorized[account] = true;
    }

    function removeAuthorized(address account) external onlyOwner {
        authorized[account] = false;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != stakingToken || paused, "Cannot withdraw staking token unless paused");

        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Emergency withdraw failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
        authorized[newOwner] = true;
    }
}
