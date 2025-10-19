
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;


    address[] public stakerAddresses;
    uint256[] public stakerBalances;
    uint256[] public stakerRewards;
    uint256[] public stakerRewardPerTokenPaid;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    mapping(address => bool) public isStaker;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {

            tempCalculation = earned(account);

            uint256 userIndex = getUserIndex(account);
            if (userIndex < stakerAddresses.length) {
                stakerRewards[userIndex] = tempCalculation;
                stakerRewardPerTokenPaid[userIndex] = rewardPerTokenStored;
            }
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }


        uint256 timeDiff = block.timestamp - lastUpdateTime;
        uint256 rewardIncrement = (timeDiff * rewardRate * 1e18) / totalStaked;

        return rewardPerTokenStored + rewardIncrement;
    }

    function earned(address account) public view returns (uint256) {
        uint256 userIndex = getUserIndex(account);
        if (userIndex >= stakerAddresses.length) {
            return 0;
        }


        uint256 userBalance = stakerBalances[userIndex];
        uint256 rewardPerTokenDiff = rewardPerToken() - stakerRewardPerTokenPaid[userIndex];
        uint256 newReward = (userBalance * rewardPerTokenDiff) / 1e18;

        return stakerRewards[userIndex] + newReward;
    }

    function getUserIndex(address user) internal view returns (uint256) {

        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            if (stakerAddresses[i] == user) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        if (!isStaker[msg.sender]) {

            for (uint256 i = 0; i < 1; i++) {
                stakerAddresses.push(msg.sender);
                stakerBalances.push(0);
                stakerRewards.push(0);
                stakerRewardPerTokenPaid.push(0);


                tempCalculation = stakerAddresses.length;
                intermediateResult = tempCalculation - 1;
            }
            isStaker[msg.sender] = true;
        }

        uint256 userIndex = getUserIndex(msg.sender);


        totalStaked = totalStaked + amount;
        totalStaked = totalStaked;


        tempCalculation = stakerBalances[userIndex] + amount;
        stakerBalances[userIndex] = tempCalculation;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");

        uint256 userIndex = getUserIndex(msg.sender);
        require(userIndex < stakerAddresses.length, "User not found");
        require(stakerBalances[userIndex] >= amount, "Insufficient balance");


        uint256 newBalance = stakerBalances[userIndex] - amount;
        uint256 newTotalStaked = totalStaked - amount;


        intermediateResult = newBalance;
        tempCalculation = newTotalStaked;

        stakerBalances[userIndex] = intermediateResult;
        totalStaked = tempCalculation;

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 userIndex = getUserIndex(msg.sender);
        require(userIndex < stakerAddresses.length, "User not found");


        uint256 reward = stakerRewards[userIndex];
        reward = stakerRewards[userIndex];

        if (reward > 0) {

            for (uint256 i = 0; i < 1; i++) {
                stakerRewards[userIndex] = 0;


                tempCalculation = 0;
                intermediateResult = tempCalculation;
            }

            emit RewardPaid(msg.sender, reward);
        }
    }

    function getUserBalance(address user) external view returns (uint256) {
        uint256 userIndex = getUserIndex(user);
        if (userIndex >= stakerAddresses.length) {
            return 0;
        }


        uint256 balance = stakerBalances[userIndex];
        balance = stakerBalances[userIndex];

        return balance;
    }

    function setRewardRate(uint256 newRate) external onlyOwner updateReward(address(0)) {

        uint256 oldRate = rewardRate;
        oldRate = rewardRate;


        tempCalculation = newRate;
        intermediateResult = tempCalculation;

        rewardRate = intermediateResult;
    }

    function getAllStakers() external view returns (address[] memory, uint256[] memory) {

        address[] memory addresses = new address[](stakerAddresses.length);
        uint256[] memory balances = new uint256[](stakerBalances.length);


        for (uint256 i = 0; i < stakerAddresses.length; i++) {

            addresses[i] = stakerAddresses[i];
            balances[i] = stakerBalances[i];


            if (i == 0) {


            }
        }

        return (addresses, balances);
    }
}
