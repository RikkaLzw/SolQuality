
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
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
    address public owner;

    mapping(address => VestingSchedule) private vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiaries[beneficiary], "Not a beneficiary");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        _createVestingSchedule(beneficiary, amount, startTime, duration, 0, true);
    }

    function createVestingScheduleWithCliff(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyOwner {
        require(cliffDuration <= duration, "Cliff exceeds duration");
        _createVestingSchedule(beneficiary, amount, startTime, duration, cliffDuration, true);
    }

    function releaseTokens() external {
        _releaseTokens(msg.sender);
    }

    function releaseTokensFor(address beneficiary) external validBeneficiary(beneficiary) {
        _releaseTokens(beneficiary);
    }

    function revokeVesting(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _computeReleasableAmount(beneficiary);
        if (releasableAmount > 0) {
            _releaseTokens(beneficiary);
        }

        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount;
        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function getVestingSchedule(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.cliffDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function computeReleasableAmount(address beneficiary) external view returns (uint256) {
        return _computeReleasableAmount(beneficiary);
    }

    function getWithdrawableAmount() external view onlyOwner returns (uint256) {
        uint256 contractBalance = token.balanceOf(address(this));
        return contractBalance > totalVestedAmount ? contractBalance - totalVestedAmount : 0;
    }

    function withdrawExcessTokens(uint256 amount) external onlyOwner {
        uint256 withdrawableAmount = this.getWithdrawableAmount();
        require(amount <= withdrawableAmount, "Insufficient withdrawable amount");
        require(token.transfer(owner, amount), "Transfer failed");
    }

    function _createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    ) private {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(startTime >= block.timestamp, "Start time in past");
        require(!beneficiaries[beneficiary], "Beneficiary already exists");

        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalVestedAmount + amount, "Insufficient contract balance");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        });

        beneficiaries[beneficiary] = true;
        totalVestedAmount += amount;

        emit VestingScheduleCreated(beneficiary, amount, startTime, duration);
    }

    function _releaseTokens(address beneficiary) private validBeneficiary(beneficiary) {
        uint256 releasableAmount = _computeReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[beneficiary].releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Transfer failed");
        emit TokensReleased(beneficiary, releasableAmount);
    }

    function _computeReleasableAmount(address beneficiary) private view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || schedule.totalAmount == 0) {
            return 0;
        }

        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 vestedAmount = _computeVestedAmount(schedule, currentTime);
        return vestedAmount - schedule.releasedAmount;
    }

    function _computeVestedAmount(VestingSchedule memory schedule, uint256 currentTime) private pure returns (uint256) {
        if (currentTime < schedule.startTime) {
            return 0;
        }

        if (currentTime >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = currentTime - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.duration;
    }
}
