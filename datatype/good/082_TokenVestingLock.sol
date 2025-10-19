
pragma solidity ^0.8.0;

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
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(msg.sender == vestingSchedules[scheduleId].beneficiary, "Not the beneficiary");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner returns (bytes32) {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_startTime >= block.timestamp, "Start time cannot be in the past");

        bytes32 scheduleId = keccak256(
            abi.encodePacked(
                _beneficiary,
                _amount,
                _startTime,
                _cliffDuration,
                _vestingDuration,
                block.timestamp,
                vestingScheduleCount[_beneficiary]
            )
        );

        require(vestingSchedules[scheduleId].beneficiary == address(0), "Schedule already exists");

        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });

        vestingScheduleCount[_beneficiary]++;
        beneficiarySchedules[_beneficiary].push(scheduleId);
        totalVestedAmount += _amount;

        emit VestingScheduleCreated(
            scheduleId,
            _beneficiary,
            _amount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );

        return scheduleId;
    }

    function release(bytes32 scheduleId) external onlyBeneficiary(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revoke(bytes32 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        }

        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount;
        schedule.revoked = true;
        totalVestedAmount -= unreleasedAmount;

        if (unreleasedAmount > 0) {
            require(token.transfer(owner, unreleasedAmount), "Token transfer failed");
        }

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

        if (schedule.revoked) {
            return schedule.releasedAmount;
        }

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
        require(contractBalance >= totalVestedAmount + amount, "Insufficient excess tokens");

        require(token.transfer(owner, amount), "Token transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
