
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLockContract {
    IERC20 public immutable token;
    address public immutable owner;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 isActive;
        string scheduleId;
        bytes metadata;
    }

    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(string => uint256) public scheduleIdToIndex;

    uint256 public totalSchedules;
    uint256 public contractStatus;
    uint256 public decimalsStorage;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        string scheduleId
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 amount,
        string scheduleId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {
        require(contractStatus == uint256(1), "Contract is not active");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
        contractStatus = uint256(1);
        decimalsStorage = uint256(18);
        totalSchedules = uint256(0);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration,
        string memory _scheduleId,
        bytes memory _metadata
    ) external onlyOwner onlyActive {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(scheduleIdToIndex[_scheduleId] == uint256(0), "Schedule ID already exists");


        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        VestingSchedule memory newSchedule = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _amount,
            releasedAmount: uint256(0),
            startTime: _startTime,
            duration: _duration,
            isActive: uint256(1),
            scheduleId: _scheduleId,
            metadata: _metadata
        });

        vestingSchedules[_beneficiary].push(newSchedule);
        totalSchedules = totalSchedules + uint256(1);
        scheduleIdToIndex[_scheduleId] = totalSchedules;

        emit VestingScheduleCreated(
            _beneficiary,
            _amount,
            _startTime,
            _duration,
            _scheduleId
        );
    }

    function releaseTokens(string memory _scheduleId) external onlyActive {
        uint256 scheduleIndex = scheduleIdToIndex[_scheduleId];
        require(scheduleIndex > uint256(0), "Schedule not found");

        address beneficiary = msg.sender;
        bool scheduleFound = false;
        uint256 foundIndex = uint256(0);


        for (uint256 i = uint256(0); i < vestingSchedules[beneficiary].length; i++) {
            if (keccak256(bytes(vestingSchedules[beneficiary][i].scheduleId)) == keccak256(bytes(_scheduleId))) {
                scheduleFound = true;
                foundIndex = i;
                break;
            }
        }

        require(scheduleFound, "Schedule not found for this beneficiary");

        VestingSchedule storage schedule = vestingSchedules[beneficiary][foundIndex];
        require(schedule.isActive == uint256(1), "Schedule is not active");
        require(block.timestamp >= schedule.startTime, "Vesting has not started yet");

        uint256 vestedAmount = calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

        require(releasableAmount > uint256(0), "No tokens available for release");

        schedule.releasedAmount = schedule.releasedAmount + releasableAmount;


        if (schedule.releasedAmount >= schedule.totalAmount) {
            schedule.isActive = uint256(0);
        }

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount, _scheduleId);
    }

    function calculateVestedAmount(VestingSchedule memory _schedule) internal view returns (uint256) {
        if (block.timestamp < _schedule.startTime) {
            return uint256(0);
        }

        if (block.timestamp >= _schedule.startTime + _schedule.duration) {
            return _schedule.totalAmount;
        }

        uint256 timeElapsed = block.timestamp - _schedule.startTime;
        return (_schedule.totalAmount * timeElapsed) / _schedule.duration;
    }

    function getVestingSchedule(address _beneficiary, uint256 _index)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 duration,
            uint256 isActive,
            string memory scheduleId,
            bytes memory metadata
        )
    {
        require(_index < vestingSchedules[_beneficiary].length, "Invalid index");

        VestingSchedule memory schedule = vestingSchedules[_beneficiary][_index];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.isActive,
            schedule.scheduleId,
            schedule.metadata
        );
    }

    function getVestingScheduleCount(address _beneficiary) external view returns (uint256) {
        return vestingSchedules[_beneficiary].length;
    }

    function getReleasableAmount(address _beneficiary, string memory _scheduleId)
        external
        view
        returns (uint256)
    {
        for (uint256 i = uint256(0); i < vestingSchedules[_beneficiary].length; i++) {
            if (keccak256(bytes(vestingSchedules[_beneficiary][i].scheduleId)) == keccak256(bytes(_scheduleId))) {
                VestingSchedule memory schedule = vestingSchedules[_beneficiary][i];
                if (schedule.isActive == uint256(1)) {
                    uint256 vestedAmount = calculateVestedAmount(schedule);
                    return vestedAmount - schedule.releasedAmount;
                }
            }
        }
        return uint256(0);
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(token), "Cannot withdraw vesting token");
        IERC20(_token).transfer(owner, _amount);
    }

    function pauseContract() external onlyOwner {
        contractStatus = uint256(0);
    }

    function unpauseContract() external onlyOwner {
        contractStatus = uint256(1);
    }
}
