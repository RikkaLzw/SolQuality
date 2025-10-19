
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
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
        uint256 vestingDuration
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier scheduleExists(bytes32 scheduleId) {
        require(vestingSchedules[scheduleId].beneficiary != address(0), "Schedule does not exist");
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
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "Cliff duration exceeds vesting duration");

        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(availableBalance >= _amount, "Insufficient contract balance");

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

        beneficiarySchedules[_beneficiary].push(scheduleId);
        vestingScheduleCount[_beneficiary]++;
        totalVestedAmount += _amount;

        emit VestingScheduleCreated(
            scheduleId,
            _beneficiary,
            _amount,
            _startTime,
            _cliffDuration,
            _vestingDuration
        );

        return scheduleId;
    }

    function release(bytes32 scheduleId) external scheduleExists(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revokeVestingSchedule(bytes32 scheduleId) external onlyOwner scheduleExists(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Schedule is not revocable");
        require(!schedule.revoked, "Schedule already revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        schedule.revoked = true;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        }

        totalVestedAmount -= unvestedAmount;

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);
    }

    function getReleasableAmount(bytes32 scheduleId) public view scheduleExists(scheduleId) returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;

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

    function getVestedAmount(bytes32 scheduleId) external view scheduleExists(scheduleId) returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return schedule.releasedAmount;
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

    function getBeneficiarySchedules(address beneficiary) external view returns (bytes32[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    function getScheduleInfo(bytes32 scheduleId) external view scheduleExists(scheduleId) returns (
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

    function withdrawUnvestedTokens(uint256 amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(amount <= availableBalance, "Insufficient available balance");
        require(token.transfer(owner, amount), "Token transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
