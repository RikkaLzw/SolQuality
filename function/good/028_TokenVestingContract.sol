
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVestingContract is ReentrancyGuard, Ownable {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) private vestingSchedules;
    uint256 public totalVestedTokens;

    event VestingCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 refundAmount);

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
    }

    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting already exists");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revoked: false
        });

        totalVestedTokens += amount;

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        emit VestingCreated(
            beneficiary,
            amount,
            block.timestamp,
            cliffDuration,
            vestingDuration
        );
    }

    function releaseTokens() external nonReentrant {
        uint256 releasableAmount = getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[msg.sender].releasedAmount += releasableAmount;
        totalVestedTokens -= releasableAmount;

        require(token.transfer(msg.sender, releasableAmount), "Token transfer failed");

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting found");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 vestedAmount = getVestedAmount(beneficiary);
        uint256 refundAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;
        totalVestedTokens -= refundAmount;

        if (refundAmount > 0) {
            require(token.transfer(owner(), refundAmount), "Token transfer failed");
        }

        emit VestingRevoked(beneficiary, refundAmount);
    }

    function getVestingSchedule(address beneficiary)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[beneficiary];
    }

    function getReleasableAmount(address beneficiary) public view returns (uint256) {
        return getVestedAmount(beneficiary) - vestingSchedules[beneficiary].releasedAmount;
    }

    function getVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return schedule.totalAmount;
        }

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;

        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.vestingDuration;

        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedTokens;
        require(amount <= availableBalance, "Insufficient available balance");
        require(token.transfer(owner(), amount), "Token transfer failed");
    }
}
