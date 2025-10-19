
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
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }


    IERC20 public immutable token;


    mapping(address => VestingSchedule) public vestingSchedules;


    address[] public beneficiaries;


    uint256 public totalLockedTokens;


    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        address indexed beneficiary,
        uint256 unreleased
    );


    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(tokenAddress);
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
        require(cliffDuration <= vestingDuration, "Cliff duration cannot exceed vesting duration");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists for beneficiary");


        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalLockedTokens.add(totalAmount), "Insufficient token balance in contract");


        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });


        beneficiaries.push(beneficiary);


        totalLockedTokens = totalLockedTokens.add(totalAmount);

        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }


    function releaseTokens(address beneficiary) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = calculateReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens available for release");


        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);


        totalLockedTokens = totalLockedTokens.sub(releasableAmount);


        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }


    function revokeVestingSchedule(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");


        uint256 releasableAmount = calculateReleasableAmount(beneficiary);


        if (releasableAmount > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(beneficiary, releasableAmount);
        }


        uint256 unreleasedAmount = schedule.totalAmount.sub(schedule.releasedAmount);


        schedule.revoked = true;


        totalLockedTokens = totalLockedTokens.sub(unreleasedAmount);

        emit VestingScheduleRevoked(beneficiary, unreleasedAmount);
    }


    function calculateReleasableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        return calculateVestedAmount(beneficiary).sub(schedule.releasedAmount);
    }


    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;


        if (currentTime < schedule.startTime) {
            return 0;
        }


        if (currentTime < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }


        if (currentTime >= schedule.startTime.add(schedule.vestingDuration)) {
            return schedule.totalAmount;
        }


        uint256 timeFromStart = currentTime.sub(schedule.startTime);
        uint256 vestedAmount = schedule.totalAmount.mul(timeFromStart).div(schedule.vestingDuration);

        return vestedAmount;
    }


    function getVestingSchedule(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool revoked
    ) {
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


    function getAllBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }


    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaries.length;
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableBalance = contractBalance.sub(totalLockedTokens);
        require(amount <= availableBalance, "Cannot withdraw locked tokens");
        require(token.transfer(owner(), amount), "Token transfer failed");
    }


    function getAvailableBalance() external view returns (uint256) {
        uint256 contractBalance = token.balanceOf(address(this));
        return contractBalance.sub(totalLockedTokens);
    }
}
