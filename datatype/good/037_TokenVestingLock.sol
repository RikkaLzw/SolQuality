
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLock {
    struct VestingSchedule {
        address beneficiary;
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

    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public vestingScheduleCount;
    mapping(address => bytes32[]) public beneficiarySchedules;

    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensReleased(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 unreleasedAmount
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(vestingSchedules[scheduleId].beneficiary == msg.sender, "Not beneficiary");
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
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner returns (bytes32) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(startTime >= block.timestamp, "Start time cannot be in the past");

        bytes32 scheduleId = keccak256(
            abi.encodePacked(
                beneficiary,
                amount,
                startTime,
                cliffDuration,
                vestingDuration,
                block.timestamp,
                vestingScheduleCount[beneficiary]
            )
        );

        require(vestingSchedules[scheduleId].beneficiary == address(0), "Schedule already exists");

        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalVestedAmount + amount, "Insufficient contract balance");

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        vestingScheduleCount[beneficiary]++;
        beneficiarySchedules[beneficiary].push(scheduleId);
        totalVestedAmount += amount;

        emit VestingScheduleCreated(
            scheduleId,
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration,
            revocable
        );

        return scheduleId;
    }

    function release(bytes32 scheduleId) external onlyBeneficiary(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Schedule revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Transfer failed");

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revokeVestingSchedule(bytes32 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.beneficiary != address(0), "Schedule does not exist");
        require(schedule.revocable, "Schedule not revocable");
        require(!schedule.revoked, "Schedule already revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Transfer failed");
            emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        }

        schedule.revoked = true;
        totalVestedAmount -= unreleasedAmount;

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unreleasedAmount);
    }

    function getReleasableAmount(bytes32 scheduleId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 vestedAmount = getVestedAmount(scheduleId);
        return vestedAmount - schedule.releasedAmount;
    }

    function getVestedAmount(bytes32 scheduleId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function getBeneficiarySchedules(address beneficiary) external view returns (bytes32[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    function getVestingSchedule(bytes32 scheduleId) external view returns (
        address beneficiary,
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];
        return (
            schedule.beneficiary,
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function withdrawExcessTokens(uint256 amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableAmount = contractBalance - totalVestedAmount;
        require(amount <= availableAmount, "Insufficient excess tokens");

        require(token.transfer(owner, amount), "Transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
