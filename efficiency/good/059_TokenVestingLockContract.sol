
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVestingLockContract is ReentrancyGuard, Ownable {
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

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public hasVestingSchedule;

    address[] public beneficiaries;
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

    modifier onlyIfVestingScheduleExists(address beneficiary) {
        require(hasVestingSchedule[beneficiary], "Vesting schedule does not exist");
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(address beneficiary) {
        require(!vestingSchedules[beneficiary].revoked, "Vesting schedule revoked");
        _;
    }

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
        require(totalAmount > 0, "Total amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(!hasVestingSchedule[beneficiary], "Vesting schedule already exists");

        uint256 currentBalance = token.balanceOf(address(this));
        uint256 availableAmount = currentBalance - (totalVestedAmount - totalReleasedAmount);
        require(availableAmount >= totalAmount, "Insufficient token balance");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        hasVestingSchedule[beneficiary] = true;
        beneficiaries.push(beneficiary);
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
        uint256 releasableAmount = _computeReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revoke(address beneficiary)
        external
        onlyOwner
        onlyIfVestingScheduleExists(beneficiary)
        onlyIfVestingScheduleNotRevoked(beneficiary)
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting schedule is not revocable");

        uint256 releasableAmount = _computeReleasableAmount(beneficiary);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(beneficiary, releasableAmount);
        }

        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount;
        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function computeReleasableAmount(address beneficiary)
        external
        view
        onlyIfVestingScheduleExists(beneficiary)
        returns (uint256)
    {
        return _computeReleasableAmount(beneficiary);
    }

    function _computeReleasableAmount(address beneficiary)
        private
        view
        onlyIfVestingScheduleExists(beneficiary)
        onlyIfVestingScheduleNotRevoked(beneficiary)
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 vestedAmount;
        if (currentTime >= schedule.startTime + schedule.vestingDuration) {
            vestedAmount = schedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime - schedule.startTime;
            vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function getVestingSchedule(address beneficiary)
        external
        view
        onlyIfVestingScheduleExists(beneficiary)
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

    function getBeneficiariesCount() external view returns (uint256) {
        return beneficiaries.length;
    }

    function withdrawExcessTokens() external onlyOwner {
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount - totalReleasedAmount;

        require(currentBalance > lockedAmount, "No excess tokens to withdraw");

        uint256 excessAmount = currentBalance - lockedAmount;
        require(token.transfer(owner(), excessAmount), "Token transfer failed");
    }
}
