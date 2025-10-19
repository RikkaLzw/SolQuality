
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
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    address public owner;

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;

    event VestingCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiaries[beneficiary], "Beneficiary not found");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        _createVestingSchedule(beneficiary, amount, startTime, duration, 0, true);
    }

    function createVestingWithCliff(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyOwner {
        require(cliffDuration <= duration, "Cliff exceeds duration");
        _createVestingSchedule(beneficiary, amount, startTime, duration, cliffDuration, true);
    }

    function createNonRevocableVesting(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        _createVestingSchedule(beneficiary, amount, startTime, duration, 0, false);
    }

    function releaseTokens() external {
        _releaseVestedTokens(msg.sender);
    }

    function releaseTokensFor(address beneficiary) external validBeneficiary(beneficiary) {
        _releaseVestedTokens(beneficiary);
    }

    function revokeVesting(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _calculateVestedAmount(beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        if (unvestedAmount > 0) {
            require(token.transfer(owner, unvestedAmount), "Transfer failed");
        }

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

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _calculateReleasableAmount(beneficiary);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        return _calculateVestedAmount(beneficiary);
    }

    function _createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    ) internal {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(startTime >= block.timestamp, "Start time in past");
        require(!beneficiaries[beneficiary], "Beneficiary exists");

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

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

        emit VestingCreated(beneficiary, amount, startTime, duration);
    }

    function _releaseVestedTokens(address beneficiary) internal validBeneficiary(beneficiary) {
        uint256 releasableAmount = _calculateReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[beneficiary].releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function _calculateReleasableAmount(address beneficiary) internal view returns (uint256) {
        uint256 vestedAmount = _calculateVestedAmount(beneficiary);
        return vestedAmount - vestingSchedules[beneficiary].releasedAmount;
    }

    function _calculateVestedAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return schedule.releasedAmount;
        }

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.duration;
        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount;
        }

        uint256 timeVested = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeVested) / schedule.duration;
    }
}
