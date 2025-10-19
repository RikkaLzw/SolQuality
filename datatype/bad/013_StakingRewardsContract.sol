
pragma solidity ^0.8.0;

contract StakingRewardsContract {

    uint256 public rewardRate = 5;
    uint256 public lockPeriod = 30;
    uint256 public maxStakers = 100;


    string public contractId = "STAKE001";
    string public version = "v1.0";


    mapping(address => bytes) public stakerData;
    bytes public contractMetadata;


    mapping(address => uint256) public isStaker;
    uint256 public contractActive = 1;
    uint256 public emergencyMode = 0;

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakeTime;
    mapping(address => uint256) public rewards;

    address public owner;
    uint256 public totalStaked;
    uint256 public rewardPool;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event RewardClaimed(address indexed staker, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyActiveContract() {
        require(contractActive == 1, "Contract not active");
        _;
    }

    modifier onlyStaker() {
        require(isStaker[msg.sender] == 1, "Not a staker");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = 1;


        contractId = "STAKE001";
        version = "v1.0";


        contractMetadata = "StakingContract";
    }

    function depositRewards() external payable onlyOwner {
        rewardPool += msg.value;
    }

    function stake() external payable onlyActiveContract {
        require(msg.value > 0, "Amount must be greater than 0");
        require(emergencyMode == 0, "Emergency mode active");


        uint256 amount = uint256(msg.value);

        if (isStaker[msg.sender] == 0) {
            isStaker[msg.sender] = 1;


            stakerData[msg.sender] = abi.encodePacked(msg.sender, block.timestamp);
        }

        stakedAmount[msg.sender] += amount;
        stakeTime[msg.sender] = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function calculateReward(address staker) public view returns (uint256) {
        if (isStaker[staker] == 0) return 0;

        uint256 stakingDuration = block.timestamp - stakeTime[staker];


        uint256 dailyReward = (stakedAmount[staker] * uint256(rewardRate)) / 100;
        uint256 daysStaked = stakingDuration / (24 * 60 * 60);

        return dailyReward * daysStaked;
    }

    function claimReward() external onlyStaker onlyActiveContract {
        require(emergencyMode == 0, "Emergency mode active");

        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards available");
        require(reward <= rewardPool, "Insufficient reward pool");

        rewards[msg.sender] += reward;
        rewardPool -= reward;
        stakeTime[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function withdraw() external onlyStaker {
        uint256 amount = stakedAmount[msg.sender];
        require(amount > 0, "No staked amount");


        uint256 stakingDuration = block.timestamp - stakeTime[msg.sender];


        require(stakingDuration >= uint256(lockPeriod) * 24 * 60 * 60, "Lock period not met");

        stakedAmount[msg.sender] = 0;
        isStaker[msg.sender] = 0;
        totalStaked -= amount;


        delete stakerData[msg.sender];

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        require(_rate <= 20, "Rate too high");
        rewardRate = _rate;
    }

    function setLockPeriod(uint256 _days) external onlyOwner {
        require(_days <= 365, "Period too long");
        lockPeriod = _days;
    }

    function toggleEmergencyMode() external onlyOwner {

        emergencyMode = emergencyMode == 0 ? 1 : 0;
    }

    function setContractActive(uint256 _active) external onlyOwner {

        require(_active <= 1, "Invalid value");
        contractActive = _active;
    }

    function updateContractMetadata(bytes memory _metadata) external onlyOwner {

        contractMetadata = _metadata;
    }

    function getStakerInfo(address staker) external view returns (
        uint256 amount,
        uint256 time,
        uint256 reward,
        uint256 isActive,
        bytes memory data
    ) {
        return (
            stakedAmount[staker],
            stakeTime[staker],
            calculateReward(staker),
            isStaker[staker],
            stakerData[staker]
        );
    }

    function getContractInfo() external view returns (
        string memory id,
        string memory ver,
        uint256 rate,
        uint256 lock,
        uint256 active,
        bytes memory metadata
    ) {
        return (
            contractId,
            version,
            rewardRate,
            lockPeriod,
            contractActive,
            contractMetadata
        );
    }
}
