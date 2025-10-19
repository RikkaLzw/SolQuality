
pragma solidity ^0.8.0;

contract TimelockTreasury {
    address public owner;
    uint256 public unlockTime;
    uint256 public lockedAmount;
    bool public fundsWithdrawn;

    event FundsDeposited(address indexed depositor, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event UnlockTimeExtended(uint256 newUnlockTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAfterUnlock() {
        require(block.timestamp >= unlockTime, "Funds are still locked");
        _;
    }

    modifier notWithdrawn() {
        require(!fundsWithdrawn, "Funds already withdrawn");
        _;
    }

    constructor(uint256 _lockDuration) {
        owner = msg.sender;
        unlockTime = block.timestamp + _lockDuration;
        fundsWithdrawn = false;
    }

    function depositFunds() external payable onlyOwner {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(!fundsWithdrawn, "Cannot deposit after withdrawal");

        lockedAmount += msg.value;
        emit FundsDeposited(msg.sender, msg.value, unlockTime);
    }

    function withdrawFunds() external onlyOwner onlyAfterUnlock notWithdrawn {
        require(lockedAmount > 0, "No funds to withdraw");

        uint256 amount = lockedAmount;
        fundsWithdrawn = true;
        lockedAmount = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(owner, amount);
    }

    function extendLockTime(uint256 _additionalTime) external onlyOwner notWithdrawn {
        require(_additionalTime > 0, "Additional time must be greater than 0");

        unlockTime += _additionalTime;
        emit UnlockTimeExtended(unlockTime);
    }

    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= unlockTime) {
            return 0;
        }
        return unlockTime - block.timestamp;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function isUnlocked() external view returns (bool) {
        return block.timestamp >= unlockTime;
    }

    receive() external payable {
        revert("Use depositFunds() function to deposit");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
