
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
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    address public immutable owner;

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyBeneficiary() {
        require(beneficiaries[msg.sender], "Not beneficiary");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_vestingDuration > 0, "Vesting duration must be > 0");
        require(!beneficiaries[_beneficiary], "Schedule already exists");

        uint256 startTime = _startTime == 0 ? block.timestamp : _startTime;

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });

        beneficiaries[_beneficiary] = true;
        totalVestedAmount += _totalAmount;

        require(
            token.transferFrom(msg.sender, address(this), _totalAmount),
            "Transfer failed"
        );

        emit VestingScheduleCreated(
            _beneficiary,
            _totalAmount,
            startTime,
            _cliffDuration,
            _vestingDuration
        );
    }

    function release() external onlyBeneficiary {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(!schedule.revoked, "Vesting revoked");

        uint256 releasableAmount = _getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(token.transfer(msg.sender, releasableAmount), "Transfer failed");

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revoke(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _getVestedAmount(_beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;
        totalVestedAmount -= unvestedAmount;

        if (unvestedAmount > 0) {
            require(token.transfer(owner, unvestedAmount), "Transfer failed");
        }

        emit VestingRevoked(_beneficiary, unvestedAmount);
    }

    function getVestingSchedule(address _beneficiary)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 vestingDuration,
            bool revocable,
            bool revoked
        )
    {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function getReleasableAmount(address _beneficiary) external view returns (uint256) {
        return _getReleasableAmount(_beneficiary);
    }

    function getVestedAmount(address _beneficiary) external view returns (uint256) {
        return _getVestedAmount(_beneficiary);
    }

    function _getReleasableAmount(address _beneficiary) internal view returns (uint256) {
        return _getVestedAmount(_beneficiary) - vestingSchedules[_beneficiary].releasedAmount;
    }

    function _getVestedAmount(address _beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.revoked || schedule.totalAmount == 0) {
            return schedule.releasedAmount;
        }

        uint256 currentTime = block.timestamp;
        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;

        if (currentTime < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.vestingDuration;

        if (currentTime >= vestingEnd) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = currentTime - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount - totalReleasedAmount;
        require(balance > lockedAmount, "No excess tokens");

        uint256 excessAmount = balance - lockedAmount;
        require(token.transfer(owner, excessAmount), "Transfer failed");
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
