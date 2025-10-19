
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
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    address public owner;

    mapping(address => VestingSchedule) private vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalLockedTokens;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
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

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(!beneficiaries[beneficiary], "Beneficiary already exists");

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: true,
            revoked: false
        });

        beneficiaries[beneficiary] = true;
        totalLockedTokens += amount;

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            block.timestamp,
            cliffDuration,
            vestingDuration
        );
    }

    function releaseTokens() external {
        address beneficiary = msg.sender;
        uint256 releasableAmount = _getReleasableAmount(beneficiary);

        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[beneficiary].releasedAmount += releasableAmount;
        totalLockedTokens -= releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _getVestedAmount(beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;
        totalLockedTokens -= unvestedAmount;

        if (unvestedAmount > 0) {
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

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _getReleasableAmount(beneficiary);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        return _getVestedAmount(beneficiary);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function _getReleasableAmount(address beneficiary) private view returns (uint256) {
        if (!beneficiaries[beneficiary]) {
            return 0;
        }

        uint256 vestedAmount = _getVestedAmount(beneficiary);
        return vestedAmount - vestingSchedules[beneficiary].releasedAmount;
    }

    function _getVestedAmount(address beneficiary) private view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked) {
            return schedule.totalAmount;
        }

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
