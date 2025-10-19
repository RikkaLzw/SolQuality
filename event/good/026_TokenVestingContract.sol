
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenVestingContract is Ownable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;
    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed amount
    );

    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed unvestedAmount
    );

    event EmergencyWithdraw(
        address indexed token,
        uint256 indexed amount,
        address indexed to
    );

    constructor(address _token) {
        require(_token != address(0), "TokenVestingContract: token address cannot be zero");
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(beneficiary != address(0), "TokenVestingContract: beneficiary cannot be zero address");
        require(totalAmount > 0, "TokenVestingContract: total amount must be greater than zero");
        require(vestingDuration > 0, "TokenVestingContract: vesting duration must be greater than zero");
        require(startTime >= block.timestamp, "TokenVestingContract: start time cannot be in the past");
        require(vestingSchedules[beneficiary].totalAmount == 0, "TokenVestingContract: vesting schedule already exists for beneficiary");

        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance >= totalVestedAmount + totalAmount,
            "TokenVestingContract: insufficient contract balance for new vesting schedule"
        );

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revoked: false
        });

        totalVestedAmount += totalAmount;

        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    function release() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "TokenVestingContract: no vesting schedule found for caller");
        require(!schedule.revoked, "TokenVestingContract: vesting schedule has been revoked");

        uint256 releasableAmount = _calculateReleasableAmount(schedule);
        require(releasableAmount > 0, "TokenVestingContract: no tokens available for release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        bool success = token.transfer(msg.sender, releasableAmount);
        require(success, "TokenVestingContract: token transfer failed");

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "TokenVestingContract: no vesting schedule found for beneficiary");
        require(!schedule.revoked, "TokenVestingContract: vesting schedule already revoked");

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            bool success = token.transfer(beneficiary, releasableAmount);
            require(success, "TokenVestingContract: token transfer failed");
            emit TokensReleased(beneficiary, releasableAmount);
        }

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }
        return _calculateReleasableAmount(schedule);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) {
            return 0;
        }
        return _calculateVestedAmount(schedule);
    }

    function emergencyWithdraw(address tokenAddress, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "TokenVestingContract: recipient cannot be zero address");
        require(amount > 0, "TokenVestingContract: amount must be greater than zero");

        if (tokenAddress == address(token)) {
            uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
            require(amount <= availableBalance, "TokenVestingContract: insufficient available balance");
        }

        IERC20 targetToken = IERC20(tokenAddress);
        bool success = targetToken.transfer(to, amount);
        require(success, "TokenVestingContract: emergency withdraw failed");

        emit EmergencyWithdraw(tokenAddress, amount, to);
    }

    function _calculateVestedAmount(VestingSchedule storage schedule) private view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function _calculateReleasableAmount(VestingSchedule storage schedule) private view returns (uint256) {
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount - schedule.releasedAmount;
    }
}
