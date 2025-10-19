
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVestingContract is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;
    uint256 public totalLockedTokens;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 refundAmount);

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        _createVesting(beneficiary, amount, startTime, duration, 0, true);
    }

    function createVestingWithCliff(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyOwner {
        require(cliffDuration <= duration, "Cliff duration exceeds total duration");
        _createVesting(beneficiary, amount, startTime, duration, cliffDuration, true);
    }

    function releaseTokens() external nonReentrant {
        uint256 releasableAmount = _getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens available for release");

        _releaseTokens(msg.sender, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule exists");
        require(schedule.revocable, "Vesting is not revocable");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        if (releasableAmount > 0) {
            _releaseTokens(beneficiary, releasableAmount);
        }

        uint256 refundAmount = schedule.totalAmount.sub(schedule.releasedAmount);
        schedule.revoked = true;
        totalLockedTokens = totalLockedTokens.sub(refundAmount);

        emit VestingRevoked(beneficiary, refundAmount);
    }

    function getVestingInfo(address beneficiary)
        external
        view
        returns (uint256, uint256, uint256, bool)
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            _getReleasableAmount(beneficiary),
            schedule.revoked
        );
    }

    function _createVesting(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    ) internal {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting already exists");

        uint256 currentBalance = token.balanceOf(address(this));
        require(currentBalance >= totalLockedTokens.add(amount), "Insufficient contract balance");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        });

        totalLockedTokens = totalLockedTokens.add(amount);

        emit VestingScheduleCreated(beneficiary, amount, startTime, duration);
    }

    function _getReleasableAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || schedule.totalAmount == 0) {
            return 0;
        }

        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        uint256 vestedAmount = _getVestedAmount(beneficiary);
        return vestedAmount.sub(schedule.releasedAmount);
    }

    function _getVestedAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        return schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
    }

    function _releaseTokens(address beneficiary, uint256 amount) internal {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        schedule.releasedAmount = schedule.releasedAmount.add(amount);
        totalLockedTokens = totalLockedTokens.sub(amount);

        require(token.transfer(beneficiary, amount), "Token transfer failed");

        emit TokensReleased(beneficiary, amount);
    }
}
