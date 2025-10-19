
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
        uint64 startTime;
        uint64 cliffDuration;
        uint64 vestingDuration;
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
        uint64 startTime,
        uint64 cliffDuration,
        uint64 vestingDuration,
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
        uint256 unvestedAmount
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyIfVestingScheduleExists(bytes32 scheduleId) {
        require(vestingSchedules[scheduleId].beneficiary != address(0), "Vesting schedule does not exist");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint64 _startTime,
        uint64 _cliffDuration,
        uint64 _vestingDuration,
        bool _revocable
    ) external onlyOwner returns (bytes32) {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "Cliff duration cannot exceed vesting duration");

        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalVestedAmount + _amount, "Insufficient contract balance");

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

        totalVestedAmount += _amount;
        vestingScheduleCount[_beneficiary]++;
        beneficiarySchedules[_beneficiary].push(scheduleId);

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

    function release(bytes32 scheduleId) external onlyIfVestingScheduleExists(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens available for release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revoke(bytes32 scheduleId) external onlyOwner onlyIfVestingScheduleExists(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");

        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount;
        uint256 releasableAmount = getReleasableAmount(scheduleId);

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");
            unvestedAmount -= releasableAmount;
        }

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);

        if (releasableAmount > 0) {
            emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        }
    }

    function getReleasableAmount(bytes32 scheduleId) public view onlyIfVestingScheduleExists(scheduleId) returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint64 currentTime = uint64(block.timestamp);

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

    function getVestingSchedule(bytes32 scheduleId) external view onlyIfVestingScheduleExists(scheduleId) returns (VestingSchedule memory) {
        return vestingSchedules[scheduleId];
    }

    function getBeneficiarySchedules(address beneficiary) external view returns (bytes32[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    function withdrawUnvestedTokens(uint256 amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableBalance = contractBalance - totalVestedAmount;
        require(amount <= availableBalance, "Insufficient unvested tokens");

        require(token.transfer(owner, amount), "Token transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
