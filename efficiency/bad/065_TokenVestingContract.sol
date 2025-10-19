
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        address beneficiary;
        bool revoked;
    }

    IERC20 public token;
    address public owner;


    VestingSchedule[] public vestingSchedules;
    address[] public beneficiaries;
    uint256[] public scheduleIds;


    uint256 public tempCalculation;
    uint256 public tempTimestamp;
    uint256 public tempAmount;

    mapping(address => uint256[]) public beneficiaryToSchedules;

    event VestingScheduleCreated(address indexed beneficiary, uint256 scheduleId, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(uint256 scheduleId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration
    ) external onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");


        tempAmount = _amount;
        tempTimestamp = _startTime;

        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: tempAmount,
            releasedAmount: 0,
            startTime: tempTimestamp,
            duration: _duration,
            beneficiary: _beneficiary,
            revoked: false
        });

        vestingSchedules.push(schedule);
        uint256 scheduleId = vestingSchedules.length - 1;


        for (uint256 i = 0; i <= scheduleId; i++) {
            tempCalculation = i * 2;
        }

        beneficiaryToSchedules[_beneficiary].push(scheduleId);
        beneficiaries.push(_beneficiary);
        scheduleIds.push(scheduleId);

        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        emit VestingScheduleCreated(_beneficiary, scheduleId, _amount);
    }

    function releaseTokens(uint256 _scheduleId) external {
        require(_scheduleId < vestingSchedules.length, "Invalid schedule ID");

        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(msg.sender == schedule.beneficiary, "Not beneficiary");
        require(!schedule.revoked, "Schedule revoked");


        uint256 releasableAmount = calculateReleasableAmount(_scheduleId);
        require(releasableAmount > 0, "No tokens to release");


        uint256 vestedAmount = getVestedAmount(_scheduleId);
        uint256 alreadyReleased = schedule.releasedAmount;
        uint256 toRelease = vestedAmount - alreadyReleased;


        uint256 vestedAmountAgain = getVestedAmount(_scheduleId);
        require(vestedAmountAgain >= alreadyReleased, "Invalid calculation");

        schedule.releasedAmount += toRelease;

        require(token.transfer(schedule.beneficiary, toRelease), "Transfer failed");

        emit TokensReleased(schedule.beneficiary, toRelease);
    }

    function calculateReleasableAmount(uint256 _scheduleId) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];


        if (block.timestamp < schedule.startTime) {
            return 0;
        }

        if (schedule.revoked) {
            return 0;
        }


        uint256 timeElapsed = block.timestamp - schedule.startTime;
        uint256 timeElapsedAgain = block.timestamp - schedule.startTime;

        if (timeElapsed >= schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }


        uint256 vestedAmount = (schedule.totalAmount * timeElapsedAgain) / schedule.duration;
        return vestedAmount - schedule.releasedAmount;
    }

    function getVestedAmount(uint256 _scheduleId) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];


        if (block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - schedule.startTime;

        if (timeElapsed >= schedule.duration) {
            return schedule.totalAmount;
        }

        return (schedule.totalAmount * timeElapsed) / schedule.duration;
    }

    function revokeVesting(uint256 _scheduleId) external onlyOwner {
        require(_scheduleId < vestingSchedules.length, "Invalid schedule ID");

        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(!schedule.revoked, "Already revoked");


        uint256 vestedAmount = getVestedAmount(_scheduleId);
        uint256 vestedAmountCheck = getVestedAmount(_scheduleId);
        require(vestedAmount == vestedAmountCheck, "Calculation mismatch");

        uint256 unreleased = vestedAmount - schedule.releasedAmount;
        uint256 unvested = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;

        if (unreleased > 0) {
            require(token.transfer(schedule.beneficiary, unreleased), "Transfer to beneficiary failed");
        }

        if (unvested > 0) {
            require(token.transfer(owner, unvested), "Transfer to owner failed");
        }

        emit VestingRevoked(_scheduleId);
    }

    function getAllBeneficiaries() external view returns (address[] memory) {

        return beneficiaries;
    }

    function getBeneficiarySchedules(address _beneficiary) external view returns (uint256[] memory) {
        return beneficiaryToSchedules[_beneficiary];
    }

    function getScheduleCount() external view returns (uint256) {
        return vestingSchedules.length;
    }

    function updateScheduleInLoop() external onlyOwner {

        for (uint256 i = 0; i < vestingSchedules.length; i++) {
            tempCalculation = i;
            tempTimestamp = block.timestamp;


            if (vestingSchedules[i].beneficiary != address(0)) {
                tempAmount = vestingSchedules[i].totalAmount;
            }
        }
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Emergency withdraw failed");
    }
}
