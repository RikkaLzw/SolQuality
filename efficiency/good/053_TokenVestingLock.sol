
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLock {
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
    address public owner;

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public hasVesting;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 startTime, uint256 cliffDuration, uint256 vestingDuration);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 revokedAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner validBeneficiary(beneficiary) {
        require(amount > 0, "Amount must be positive");
        require(vestingDuration > 0, "Vesting duration must be positive");
        require(!hasVesting[beneficiary], "Vesting already exists");
        require(startTime >= block.timestamp, "Start time in past");

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
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

        hasVesting[beneficiary] = true;
        totalVestedAmount += amount;

        emit VestingCreated(beneficiary, amount, startTime, cliffDuration, vestingDuration);
    }

    function release() external {
        address beneficiary = msg.sender;
        require(hasVesting[beneficiary], "No vesting schedule");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        require(hasVesting[beneficiary], "No vesting schedule");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        uint256 revokedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
        }

        if (revokedAmount > 0) {
            totalVestedAmount -= revokedAmount;
            require(token.transfer(owner, revokedAmount), "Token transfer failed");
        }

        schedule.revoked = true;

        emit VestingRevoked(beneficiary, revokedAmount);
        if (releasableAmount > 0) {
            emit TokensReleased(beneficiary, releasableAmount);
        }
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _getReleasableAmount(beneficiary);
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
        require(hasVesting[beneficiary], "No vesting schedule");
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

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function emergencyWithdraw(address emergencyToken, uint256 amount) external onlyOwner {
        require(emergencyToken != address(token), "Cannot withdraw vested token");
        IERC20(emergencyToken).transfer(owner, amount);
    }

    function _getReleasableAmount(address beneficiary) private view returns (uint256) {
        if (!hasVesting[beneficiary]) {
            return 0;
        }

        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;
        uint256 cliffTime = schedule.startTime + schedule.cliffDuration;

        if (currentTime < cliffTime) {
            return 0;
        }

        uint256 vestingEndTime = schedule.startTime + schedule.vestingDuration;
        uint256 vestedAmount;

        if (currentTime >= vestingEndTime) {
            vestedAmount = schedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime - schedule.startTime;
            vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        }

        return vestedAmount - schedule.releasedAmount;
    }
}
