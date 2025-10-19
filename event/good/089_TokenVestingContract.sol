
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
        uint256 totalAmount,
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
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner returns (bytes32) {
        require(_beneficiary != address(0), "TokenVesting: beneficiary address cannot be zero");
        require(_totalAmount > 0, "TokenVesting: total amount must be greater than zero");
        require(_vestingDuration > 0, "TokenVesting: vesting duration must be greater than zero");
        require(_startTime >= block.timestamp, "TokenVesting: start time cannot be in the past");
        require(
            _cliffDuration <= _vestingDuration,
            "TokenVesting: cliff duration cannot exceed vesting duration"
        );


        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance >= totalVestedAmount + _totalAmount,
            "TokenVesting: insufficient token balance in contract"
        );

        bytes32 scheduleId = keccak256(
            abi.encodePacked(_beneficiary, _totalAmount, _startTime, vestingScheduleCount[_beneficiary])
        );

        require(
            vestingSchedules[scheduleId].beneficiary == address(0),
            "TokenVesting: vesting schedule already exists"
        );

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });

        beneficiarySchedules[_beneficiary].push(scheduleId);
        vestingScheduleCount[_beneficiary]++;
        totalVestedAmount += _totalAmount;

        emit VestingScheduleCreated(
            scheduleId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );

        return scheduleId;
    }

    function release(bytes32 scheduleId) external onlyBeneficiary(scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];

        require(!schedule.revoked, "TokenVesting: vesting schedule has been revoked");

        uint256 releasableAmount = getReleasableAmount(scheduleId);
        require(releasableAmount > 0, "TokenVesting: no tokens available for release");

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

        require(schedule.beneficiary != address(0), "TokenVesting: vesting schedule does not exist");
        require(schedule.revocable, "TokenVesting: vesting schedule is not revocable");
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 vestedAmount = getVestedAmount(scheduleId);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;


        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(schedule.beneficiary, releasableAmount),
                "TokenVesting: token transfer to beneficiary failed"
            );
            emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        }

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);
    }

    function getVestedAmount(bytes32 scheduleId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.beneficiary == address(0)) {
            return 0;
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

    function getReleasableAmount(bytes32 scheduleId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint256 vestedAmount = getVestedAmount(scheduleId);
        return vestedAmount - schedule.releasedAmount;
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

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TokenVesting: new owner address cannot be zero");
        require(newOwner != owner, "TokenVesting: new owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function withdrawUnvestedTokens() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 withdrawableAmount = contractBalance - totalVestedAmount;

        require(withdrawableAmount > 0, "TokenVesting: no unvested tokens available for withdrawal");

        require(
            token.transfer(owner, withdrawableAmount),
            "TokenVesting: token transfer failed"
        );
    }

    function getContractTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
