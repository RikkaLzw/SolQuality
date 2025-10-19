
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalPointsIssued;

    mapping(address => uint256) public userPoints;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => RewardTier) public rewardTiers;
    mapping(address => uint256) public userRedemptions;

    struct RewardTier {
        uint256 pointsRequired;
        string rewardName;
        bool active;
    }

    uint256 public nextTierId = 1;


    event PointsAwarded(address user, uint256 amount, string reason);
    event PointsRedeemed(address user, uint256 tierId, uint256 pointsSpent);
    event RewardTierCreated(uint256 tierId, uint256 pointsRequired, string rewardName);


    error Err1();
    error Err2();
    error Err3();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedMinters[msg.sender] = true;
    }

    function addAuthorizedMinter(address minter) external onlyOwner {

        authorizedMinters[minter] = true;
    }

    function removeAuthorizedMinter(address minter) external onlyOwner {
        require(minter != owner);

        authorizedMinters[minter] = false;
    }

    function awardPoints(address user, uint256 amount, string memory reason) external onlyAuthorized {
        require(user != address(0));
        require(amount > 0);

        userPoints[user] += amount;
        totalPointsIssued += amount;

        emit PointsAwarded(user, amount, reason);
    }

    function createRewardTier(uint256 pointsRequired, string memory rewardName) external onlyOwner {
        require(pointsRequired > 0);
        require(bytes(rewardName).length > 0);

        rewardTiers[nextTierId] = RewardTier({
            pointsRequired: pointsRequired,
            rewardName: rewardName,
            active: true
        });

        emit RewardTierCreated(nextTierId, pointsRequired, rewardName);
        nextTierId++;
    }

    function deactivateRewardTier(uint256 tierId) external onlyOwner {
        require(rewardTiers[tierId].pointsRequired > 0);

        rewardTiers[tierId].active = false;
    }

    function redeemReward(uint256 tierId) external {
        RewardTier memory tier = rewardTiers[tierId];


        require(tier.pointsRequired > 0);
        require(tier.active);
        require(userPoints[msg.sender] >= tier.pointsRequired);

        userPoints[msg.sender] -= tier.pointsRequired;
        userRedemptions[msg.sender]++;

        emit PointsRedeemed(msg.sender, tierId, tier.pointsRequired);
    }

    function transferPoints(address to, uint256 amount) external {
        require(to != address(0));
        require(amount > 0);

        if (userPoints[msg.sender] < amount) {

            revert Err1();
        }

        userPoints[msg.sender] -= amount;
        userPoints[to] += amount;


    }

    function burnPoints(address user, uint256 amount) external onlyAuthorized {
        require(user != address(0));

        if (userPoints[user] < amount) {

            revert Err2();
        }

        userPoints[user] -= amount;

    }

    function setPointsDirectly(address user, uint256 newAmount) external onlyOwner {
        require(user != address(0));


        userPoints[user] = newAmount;
    }

    function emergencyWithdraw() external onlyOwner {

        if (address(this).balance == 0) {
            revert Err3();
        }

        payable(owner).transfer(address(this).balance);
    }

    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

    function getRewardTier(uint256 tierId) external view returns (RewardTier memory) {
        return rewardTiers[tierId];
    }

    function isAuthorizedMinter(address account) external view returns (bool) {
        return authorizedMinters[account];
    }

    receive() external payable {}
}
