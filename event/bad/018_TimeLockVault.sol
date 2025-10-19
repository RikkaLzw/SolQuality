
pragma solidity ^0.8.0;

contract TimeLockVault {
    mapping(address => uint256) private balances;
    mapping(address => uint256) private unlockTimes;
    address public owner;
    uint256 public minimumDelay;

    event Deposit(address user, uint256 amount);
    event Withdrawal(address user, uint256 amount);
    event DelayUpdated(uint256 newDelay);

    error InvalidDelay();
    error NoFunds();
    error NotOwner();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(uint256 _minimumDelay) {
        owner = msg.sender;
        minimumDelay = _minimumDelay;
    }

    function deposit(uint256 _lockDuration) external payable {
        require(msg.value > 0);
        require(_lockDuration >= minimumDelay);

        balances[msg.sender] += msg.value;
        unlockTimes[msg.sender] = block.timestamp + _lockDuration;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        require(balances[msg.sender] > 0);
        require(block.timestamp >= unlockTimes[msg.sender]);

        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount);
    }

    function extendLockTime(uint256 _additionalTime) external {
        require(balances[msg.sender] > 0);
        require(_additionalTime > 0);

        unlockTimes[msg.sender] += _additionalTime;
    }

    function updateMinimumDelay(uint256 _newDelay) external onlyOwner {
        require(_newDelay > 0);

        minimumDelay = _newDelay;

        emit DelayUpdated(_newDelay);
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0);

        payable(owner).transfer(address(this).balance);
    }

    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getUnlockTime(address _user) external view returns (uint256) {
        return unlockTimes[_user];
    }

    function isUnlocked(address _user) external view returns (bool) {
        return block.timestamp >= unlockTimes[_user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
