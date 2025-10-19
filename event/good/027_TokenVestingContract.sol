
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
        uint256 totalAmount,
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
        require(msg.sender == owner, "TokenVesting: caller is not the owner");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(
            vestingSchedules[scheduleId].beneficiary == msg.sender,
            "TokenVesting: caller is not the beneficiary"
        );
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "TokenVesting: token address cannot be zero");
        token = IERC20(_token);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) external onlyOwner returns (bytes32) {
        require(_beneficiary != address(0), "TokenVesting: beneficiary address cannot be zero");
        require(_totalAmount > 0, "TokenVesting: total amount must be greater than zero");
        require(_vestingDuration > 0, "TokenVesting: vesting duration must be greater than zero");
        require(_startTime >= block.timestamp, "TokenVesting: start time cannot be in the past");

        bytes32 scheduleId = keccak256(
            abi.encodePacked(
                _beneficiary,
                _totalAmount,
                _startTime,
                _cliffDuration,
                _vestingDuration,
                block.timestamp,
                vestingScheduleCount[_beneficiary]
            )
        );

        require(
            vestingSchedules[scheduleId].beneficiary == address(0),
            "TokenVesting: vesting schedule already exists"
        );

        require(
            token.transferFrom(msg.sender, address(this), _totalAmount),
            "TokenVesting: token transfer failed"
        );

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revoked: false
        });

        vestingScheduleCount[_beneficiary]++;
        beneficiarySchedules[_beneficiary].push(scheduleId);
        totalVestedAmount += _totalAmount;

        emit VestingScheduleCreated(
            scheduleId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration
        );

        return scheduleId;
    }

    function release(bytes32 scheduleId) external onlyBeneficiary(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];

        require(!schedule.revoked, "TokenVesting: vesting schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "TokenVesting: no tokens are due for release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(
            token.transfer(schedule.beneficiary, releasableAmount),
            "TokenVesting: token transfer failed"
        );

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revokeVestingSchedule(bytes32 scheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];

        require(
            schedule.beneficiary != address(0),
            "TokenVesting: vesting schedule does not exist"
        );
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        uint256 unvestedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        schedule.revoked = true;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(schedule.beneficiary, releasableAmount),
                "TokenVesting: token transfer to beneficiary failed"
            );
        }

        if (unvestedAmount > 0) {
            totalVestedAmount -= unvestedAmount;
            require(
                token.transfer(owner, unvestedAmount),
                "TokenVesting: token transfer to owner failed"
            );
        }

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);
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
            schedule.revoked
        );
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TokenVesting: new owner cannot be zero address");
        require(newOwner != owner, "TokenVesting: new owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function emergencyWithdraw(address _token, uint256 amount) external onlyOwner {
        require(_token != address(token), "TokenVesting: cannot withdraw vested tokens");
        require(amount > 0, "TokenVesting: amount must be greater than zero");

        IERC20(_token).transfer(owner, amount);
    }
}
