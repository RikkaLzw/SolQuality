
pragma solidity ^0.8.0;

contract TimeLockTreasury {
    address public owner;
    uint256 public lockDuration;
    uint256 public creationTime;
    bool public fundsReleased;

    mapping(address => uint256) public lockedBalances;
    mapping(address => uint256) public lockTimestamps;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAfterLock() {
        require(block.timestamp >= creationTime + lockDuration, "Funds still locked");
        _;
    }

    constructor(uint256 _lockDuration) {
        owner = msg.sender;
        lockDuration = _lockDuration;
        creationTime = block.timestamp;
        fundsReleased = false;
    }

    function lockFunds() external payable {
        require(msg.value > 0, "Must send ETH");
        require(!fundsReleased, "Contract funds already released");

        lockedBalances[msg.sender] += msg.value;
        lockTimestamps[msg.sender] = block.timestamp;

        emit FundsLocked(msg.sender, msg.value, block.timestamp + lockDuration);
    }

    function withdrawFunds() external {
        uint256 userBalance = lockedBalances[msg.sender];
        require(userBalance > 0, "No funds to withdraw");
        require(_isUnlocked(msg.sender), "Funds still locked");

        lockedBalances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: userBalance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, userBalance);
    }

    function emergencyWithdraw() external onlyOwner onlyAfterLock {
        require(!fundsReleased, "Funds already released");

        fundsReleased = true;
        uint256 contractBalance = address(this).balance;

        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Emergency withdrawal failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= creationTime + lockDuration) {
            return 0;
        }
        return (creationTime + lockDuration) - block.timestamp;
    }

    function getUserBalance(address user) external view returns (uint256) {
        return lockedBalances[user];
    }

    function isUnlocked(address user) external view returns (bool) {
        return _isUnlocked(user);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function _isUnlocked(address user) internal view returns (bool) {
        return block.timestamp >= lockTimestamps[user] + lockDuration;
    }
}
