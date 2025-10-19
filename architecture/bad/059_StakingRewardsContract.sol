
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    address public rewardToken;
    address public stakingToken;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewardBalances;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public userRewardPerTokenPaid;

    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTimeGlobal;
    uint256 public rewardPerTokenStored;
    uint256 public rewardsDuration;
    uint256 public periodFinish;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardsDuration = 604800;
    }

    function stake(uint256 amount) external {

        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTimeGlobal = block.timestamp;
        if (stakedBalances[msg.sender] > 0) {
            rewardBalances[msg.sender] = rewardBalances[msg.sender] + ((stakedBalances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        lastUpdateTime[msg.sender] = block.timestamp;


        if (amount <= 0) {
            revert("Cannot stake 0");
        }


        (bool success, bytes memory data) = stakingToken.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
        if (!success) {
            revert("Balance check failed");
        }
        uint256 balance = abi.decode(data, (uint256));
        if (balance < amount) {
            revert("Insufficient balance");
        }


        (bool transferSuccess,) = stakingToken.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount));
        if (!transferSuccess) {
            revert("Transfer failed");
        }

        stakedBalances[msg.sender] = stakedBalances[msg.sender] + amount;
        totalStaked = totalStaked + amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {

        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTimeGlobal = block.timestamp;
        if (stakedBalances[msg.sender] > 0) {
            rewardBalances[msg.sender] = rewardBalances[msg.sender] + ((stakedBalances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        lastUpdateTime[msg.sender] = block.timestamp;


        if (amount <= 0) {
            revert("Cannot withdraw 0");
        }


        if (stakedBalances[msg.sender] < amount) {
            revert("Insufficient staked balance");
        }

        stakedBalances[msg.sender] = stakedBalances[msg.sender] - amount;
        totalStaked = totalStaked - amount;


        (bool success,) = stakingToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
        if (!success) {
            revert("Transfer failed");
        }

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external {

        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTimeGlobal = block.timestamp;
        if (stakedBalances[msg.sender] > 0) {
            rewardBalances[msg.sender] = rewardBalances[msg.sender] + ((stakedBalances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        lastUpdateTime[msg.sender] = block.timestamp;

        uint256 reward = rewardBalances[msg.sender];
        if (reward > 0) {
            rewardBalances[msg.sender] = 0;


            (bool success, bytes memory data) = rewardToken.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
            if (!success) {
                revert("Balance check failed");
            }
            uint256 contractBalance = abi.decode(data, (uint256));
            if (contractBalance < reward) {
                revert("Insufficient reward tokens in contract");
            }

            (bool transferSuccess,) = rewardToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward));
            if (!transferSuccess) {
                revert("Reward transfer failed");
            }

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {

        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTimeGlobal = block.timestamp;
        if (stakedBalances[msg.sender] > 0) {
            rewardBalances[msg.sender] = rewardBalances[msg.sender] + ((stakedBalances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        lastUpdateTime[msg.sender] = block.timestamp;

        uint256 stakedAmount = stakedBalances[msg.sender];
        uint256 reward = rewardBalances[msg.sender];

        if (stakedAmount > 0) {
            stakedBalances[msg.sender] = 0;
            totalStaked = totalStaked - stakedAmount;

            (bool success,) = stakingToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, stakedAmount));
            if (!success) {
                revert("Staking token transfer failed");
            }

            emit Withdrawn(msg.sender, stakedAmount);
        }

        if (reward > 0) {
            rewardBalances[msg.sender] = 0;

            (bool success, bytes memory data) = rewardToken.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
            if (!success) {
                revert("Balance check failed");
            }
            uint256 contractBalance = abi.decode(data, (uint256));
            if (contractBalance < reward) {
                revert("Insufficient reward tokens in contract");
            }

            (bool transferSuccess,) = rewardToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward));
            if (!transferSuccess) {
                revert("Reward transfer failed");
            }

            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external {

        if (msg.sender != owner) {
            revert("Only owner can notify reward amount");
        }


        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTimeGlobal = block.timestamp;

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / 604800;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / 604800;
        }

        lastUpdateTimeGlobal = block.timestamp;
        periodFinish = block.timestamp + 604800;


        (bool success, bytes memory data) = rewardToken.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        if (!success) {
            revert("Balance check failed");
        }
        uint256 balance = abi.decode(data, (uint256));
        if (balance < reward) {
            revert("Provided reward too high");
        }
    }

    function earned(address account) external view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0) {
            currentRewardPerToken = currentRewardPerToken + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
        }
        return rewardBalances[account] + ((stakedBalances[account] * (currentRewardPerToken - userRewardPerTokenPaid[account])) / 1e18);
    }

    function rewardPerToken() external view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTimeGlobal) * rewardRate * 1e18) / totalStaked);
    }

    function lastTimeRewardApplicable() external view returns (uint256) {
        if (block.timestamp < periodFinish) {
            return block.timestamp;
        } else {
            return periodFinish;
        }
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * 604800;
    }

    function balanceOf(address account) external view returns (uint256) {
        return stakedBalances[account];
    }

    function totalSupply() external view returns (uint256) {
        return totalStaked;
    }

    function setOwner(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can set new owner");
        }
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }
        owner = newOwner;
    }

    function emergencyWithdraw(address token, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }

        (bool success,) = token.call(abi.encodeWithSignature("transfer(address,uint256)", owner, amount));
        if (!success) {
            revert("Emergency withdraw failed");
        }
    }

    function setRewardsDuration(uint256 _rewardsDuration) external {

        if (msg.sender != owner) {
            revert("Only owner can set rewards duration");
        }
        if (block.timestamp <= periodFinish) {
            revert("Previous rewards period must be complete before changing the duration");
        }
        rewardsDuration = _rewardsDuration;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external {

        if (msg.sender != owner) {
            revert("Only owner can recover tokens");
        }
        if (tokenAddress == stakingToken) {
            revert("Cannot withdraw the staking token");
        }

        (bool success,) = tokenAddress.call(abi.encodeWithSignature("transfer(address,uint256)", owner, tokenAmount));
        if (!success) {
            revert("Token recovery failed");
        }
    }
}
