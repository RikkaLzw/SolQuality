
pragma solidity ^0.8.0;

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

    mapping(address => VestingSchedule) private vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedTokens;

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
        require(msg.sender == owner, "Not the owner");
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
        require(!beneficiaries[beneficiary], "Beneficiary already exists");
        require(startTime >= block.timestamp, "Start time in the past");

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
        totalVestedTokens += amount;

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        emit VestingScheduleCreated(beneficiary, amount, startTime, duration);
    }

    function release() external {
        _release(msg.sender);
    }

    function releaseFor(address beneficiary) external validBeneficiary(beneficiary) {
        _release(beneficiary);
    }

    function _release(address beneficiary) internal validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "Vesting revoked");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        totalVestedTokens -= releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revoke(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        schedule.revoked = true;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(beneficiary, releasableAmount);
        }

        if (unvestedAmount > 0) {
            totalVestedTokens -= unvestedAmount;
            require(token.transfer(owner, unvestedAmount), "Token transfer failed");
        }

        emit VestingRevoked(beneficiary, unvestedAmount);
    }

    function getVestingSchedule(address beneficiary)
        external
        view
        validBeneficiary(beneficiary)
        returns (VestingSchedule memory)
    {
        return vestingSchedules[beneficiary];
    }

    function getReleasableAmount(address beneficiary)
        external
        view
        validBeneficiary(beneficiary)
        returns (uint256)
    {
        return _getReleasableAmount(beneficiary);
    }

    function _getReleasableAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.duration;
        uint256 vestedAmount;

        if (block.timestamp >= vestingEnd) {
            vestedAmount = schedule.totalAmount;
        } else {
            uint256 timeFromStart = block.timestamp - schedule.startTime;
            vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function getVestedAmount(address beneficiary)
        external
        view
        validBeneficiary(beneficiary)
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return schedule.releasedAmount;
        }

        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;
        if (block.timestamp < cliffEnd) {
            return schedule.releasedAmount;
        }

        uint256 vestingEnd = schedule.startTime + schedule.duration;

        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.duration;
    }

    function withdrawExcessTokens() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > totalVestedTokens, "No excess tokens");

        uint256 excessAmount = contractBalance - totalVestedTokens;
        require(token.transfer(owner, excessAmount), "Token transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
