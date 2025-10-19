
pragma solidity ^0.8.0;

contract StakingRewardsContract {

    uint256 public rewardRate = 10;
    uint256 public stakingPeriod = 30;
    uint256 public minStakeAmount = 100;


    string public contractId = "STAKE001";
    string public version = "v1.0";


    bytes public contractHash;
    bytes public adminSignature;


    uint256 public isActive = 1;
    uint256 public emergencyStop = 0;

    address public owner;
    uint256 public totalStaked;
    uint256 public rewardPool;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 claimed;
        uint256 rewardMultiplier;
    }

    mapping(address => Stake[]) public stakes;
    mapping(address => uint256) public totalUserStake;

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Rewarded(address indexed user, uint256 reward);
    event Withdrawn(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier whenActive() {
        require(isActive == 1, "Contract not active");
        require(emergencyStop == 0, "Emergency stop activated");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractHash = abi.encodePacked(block.timestamp, msg.sender);
        adminSignature = abi.encodePacked("ADMIN_SIG_", block.number);
        isActive = 1;
        emergencyStop = 0;
    }

    function stake(uint256 amount) external payable whenActive {

        require(uint256(amount) >= uint256(minStakeAmount), "Amount too low");
        require(msg.value == amount, "Incorrect ETH sent");

        stakes[msg.sender].push(Stake({
            amount: amount,
            timestamp: block.timestamp,
            claimed: 0,
            rewardMultiplier: uint256(rewardRate)
        }));

        totalUserStake[msg.sender] += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount, block.timestamp);
    }

    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
        require(stakeIndex < stakes[user].length, "Invalid stake index");

        Stake memory userStake = stakes[user][stakeIndex];


        if (userStake.claimed == 1) {
            return 0;
        }

        uint256 stakingDuration = (block.timestamp - userStake.timestamp) / 1 days;


        if (uint256(stakingDuration) >= uint256(stakingPeriod)) {
            return (userStake.amount * uint256(userStake.rewardMultiplier)) / 100;
        }

        return 0;
    }

    function claimReward(uint256 stakeIndex) external whenActive {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        require(stakes[msg.sender][stakeIndex].claimed == 0, "Already claimed");

        uint256 reward = calculateReward(msg.sender, stakeIndex);
        require(reward > 0, "No reward available");
        require(address(this).balance >= reward, "Insufficient contract balance");

        stakes[msg.sender][stakeIndex].claimed = 1;

        payable(msg.sender).transfer(reward);

        emit Rewarded(msg.sender, reward);
    }

    function withdraw(uint256 stakeIndex) external {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake memory userStake = stakes[msg.sender][stakeIndex];
        uint256 stakingDuration = (block.timestamp - userStake.timestamp) / 1 days;


        require(uint256(stakingDuration) >= uint256(stakingPeriod), "Staking period not completed");

        uint256 amount = userStake.amount;


        stakes[msg.sender][stakeIndex] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();

        totalUserStake[msg.sender] -= amount;
        totalStaked -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function fundRewardPool() external payable onlyOwner {
        rewardPool += msg.value;
    }

    function updateRewardRate(uint256 newRate) external onlyOwner {

        rewardRate = uint256(newRate);
    }

    function setContractStatus(uint256 active) external onlyOwner {

        isActive = active;
    }

    function emergencyStopToggle(uint256 stop) external onlyOwner {

        emergencyStop = stop;
    }

    function updateContractId(string memory newId) external onlyOwner {

        contractId = newId;
    }

    function getStakeCount(address user) external view returns (uint256) {
        return stakes[user].length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function getContractHash() external view returns (bytes memory) {
        return contractHash;
    }

    function isContractActive() external view returns (uint256) {

        if (isActive == 1 && emergencyStop == 0) {
            return 1;
        }
        return 0;
    }
}
