
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => bool) public hasStaked;
    address[] public stakers;
    uint256 public totalStaked;
    uint256 public contractBalance;
    bool public contractActive;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ContractFunded(uint256 amount);

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }

    function stakeTokens() external payable {

        if (msg.sender != owner && contractActive == false) {
            revert("Contract not active");
        }
        if (msg.sender != owner && contractActive == false) {
            revert("Contract not active");
        }

...

Let me reevaluate and take a different approach.
