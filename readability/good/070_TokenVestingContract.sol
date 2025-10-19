
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

    event TokensReleased(
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(
        address indexed beneficiary,
        uint256 unvestedAmount
    );


    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }


    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Total amount must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "Cliff duration cannot exceed vesting duration");
        require(vestingSchedules[_beneficiary].totalAmount == 0, "Vesting schedule already exists for beneficiary");


        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalVestedAmount.add(_totalAmount), "Insufficient token balance in contract");


        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });


        beneficiaries.push(_beneficiary);


        totalVestedAmount = totalVestedAmount.add(_totalAmount);

        emit VestingScheduleCreated(
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );
    }


    function releaseTokens(address _beneficiary) external nonReentrant {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");

        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found for beneficiary");
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = calculateReleasableAmount(_beneficiary);
        require(releasableAmount > 0, "No tokens available for release");


        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        totalReleasedAmount = totalReleasedAmount.add(releasableAmount);


        require(token.transfer(_beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(_beneficiary, releasableAmount);
    }


    function revokeVesting(address _beneficiary) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");

        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found for beneficiary");
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");


        uint256 unvestedAmount = schedule.totalAmount.sub(schedule.releasedAmount);


        schedule.revoked = true;


        totalVestedAmount = totalVestedAmount.sub(unvestedAmount);

        emit VestingRevoked(_beneficiary, unvestedAmount);
    }


    function calculateReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        return calculateVestedAmount(_beneficiary).sub(schedule.releasedAmount);
    }


    function calculateVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

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


    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaries.length;
    }


    function getVestingSchedule(address _beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
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


    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");

        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount.sub(totalReleasedAmount);
        uint256 availableAmount = contractBalance.sub(lockedAmount);

        require(_amount <= availableAmount, "Insufficient available balance");
        require(token.transfer(owner(), _amount), "Token transfer failed");
    }


    function getAvailableBalance() external view returns (uint256) {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount.sub(totalReleasedAmount);

        if (contractBalance >= lockedAmount) {
            return contractBalance.sub(lockedAmount);
        }

        return 0;
    }
}
