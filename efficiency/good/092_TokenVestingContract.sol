
pragma solidity ^0.8.0;

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
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;

    mapping(address => VestingSchedule) private _vestingSchedules;
    mapping(address => bool) public beneficiaryExists;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(!beneficiaryExists[beneficiary], "Vesting schedule already exists");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(vestingDuration > 0, "Vesting duration must be greater than zero");
        require(startTime >= block.timestamp, "Start time cannot be in the past");

        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableAmount = contractBalance - (totalVestedAmount - totalReleasedAmount);
        require(availableAmount >= totalAmount, "Insufficient contract balance");

        _vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        beneficiaryExists[beneficiary] = true;
        totalVestedAmount += totalAmount;

        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            revocable
        );
    }

    function release() external nonReentrant {
        address beneficiary = msg.sender;
        require(beneficiaryExists[beneficiary], "No vesting schedule found");

        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens available for release");

        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revoke(address beneficiary) external onlyOwner {
        require(beneficiaryExists[beneficiary], "No vesting schedule found");

        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");

        uint256 vestedAmount = _computeVestedAmount(schedule);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function getVestingSchedule(address beneficiary)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 vestingDuration,
            bool revocable,
            bool revoked
        )
    {
        require(beneficiaryExists[beneficiary], "No vesting schedule found");
        VestingSchedule storage schedule = _vestingSchedules[beneficiary];

        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        if (!beneficiaryExists[beneficiary]) {
            return 0;
        }

        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        if (schedule.revoked) {
            return 0;
        }

        return _computeReleasableAmount(schedule);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        if (!beneficiaryExists[beneficiary]) {
            return 0;
        }

        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        return _computeVestedAmount(schedule);
    }

    function _computeReleasableAmount(VestingSchedule storage schedule)
        private
        view
        returns (uint256)
    {
        uint256 vestedAmount = _computeVestedAmount(schedule);
        return vestedAmount - schedule.releasedAmount;
    }

    function _computeVestedAmount(VestingSchedule storage schedule)
        private
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 vestingEndTime = schedule.startTime + schedule.vestingDuration;
        if (currentTime >= vestingEndTime) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = currentTime - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function withdrawExcessTokens() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount - totalReleasedAmount;

        require(contractBalance > lockedAmount, "No excess tokens to withdraw");

        uint256 excessAmount = contractBalance - lockedAmount;
        require(token.transfer(owner(), excessAmount), "Token transfer failed");
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");
        require(token.transfer(owner(), contractBalance), "Token transfer failed");
    }
}
