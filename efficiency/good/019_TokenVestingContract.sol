
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
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;

    mapping(address => VestingSchedule) private vestingSchedules;
    mapping(address => bool) public hasVestingSchedule;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);

    constructor(IERC20 _token) {
        token = _token;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(!hasVestingSchedule[beneficiary], "Schedule already exists");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(startTime >= block.timestamp, "Start time cannot be in the past");

        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance >= totalVestedAmount + amount - totalReleasedAmount,
            "Insufficient contract balance"
        );

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        hasVestingSchedule[beneficiary] = true;
        totalVestedAmount += amount;

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    function release() external nonReentrant {
        address beneficiary = msg.sender;
        require(hasVestingSchedule[beneficiary], "No vesting schedule");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "Vesting revoked");

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        token.transfer(beneficiary, releasableAmount);

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        require(hasVestingSchedule[beneficiary], "No vesting schedule");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            token.transfer(beneficiary, releasableAmount);
        }

        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount;
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
        require(hasVestingSchedule[beneficiary], "No vesting schedule");
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
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
        if (!hasVestingSchedule[beneficiary]) {
            return 0;
        }
        return _computeReleasableAmount(vestingSchedules[beneficiary]);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        if (!hasVestingSchedule[beneficiary]) {
            return 0;
        }
        return _computeVestedAmount(vestingSchedules[beneficiary]);
    }

    function withdrawExcessTokens(uint256 amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount - totalReleasedAmount;
        require(contractBalance >= lockedAmount + amount, "Insufficient excess tokens");

        token.transfer(owner(), amount);
    }

    function _computeReleasableAmount(VestingSchedule memory schedule)
        private
        view
        returns (uint256)
    {
        if (schedule.revoked) {
            return 0;
        }
        return _computeVestedAmount(schedule) - schedule.releasedAmount;
    }

    function _computeVestedAmount(VestingSchedule memory schedule)
        private
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (currentTime >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = currentTime - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }
}
