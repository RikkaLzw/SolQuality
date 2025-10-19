
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
    address public owner;

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed amount
    );

    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed unreleased
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "TokenVesting: caller is not the owner");
        _;
    }

    modifier onlyBeneficiary() {
        require(beneficiaries[msg.sender], "TokenVesting: caller is not a beneficiary");
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
    ) external onlyOwner {
        require(_beneficiary != address(0), "TokenVesting: beneficiary address cannot be zero");
        require(_totalAmount > 0, "TokenVesting: total amount must be greater than zero");
        require(_vestingDuration > 0, "TokenVesting: vesting duration must be greater than zero");
        require(_cliffDuration <= _vestingDuration, "TokenVesting: cliff duration cannot exceed vesting duration");
        require(!beneficiaries[_beneficiary], "TokenVesting: beneficiary already has a vesting schedule");

        uint256 startTime = _startTime == 0 ? block.timestamp : _startTime;
        require(startTime >= block.timestamp, "TokenVesting: start time cannot be in the past");

        require(
            token.transferFrom(msg.sender, address(this), _totalAmount),
            "TokenVesting: token transfer failed"
        );

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

        emit VestingScheduleCreated(
            _beneficiary,
            _totalAmount,
            startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );
    }

    function release() external onlyBeneficiary {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(!schedule.revoked, "TokenVesting: vesting schedule has been revoked");

        uint256 releasableAmount = _releasableAmount(msg.sender);
        require(releasableAmount > 0, "TokenVesting: no tokens are due for release");

        schedule.releasedAmount += releasableAmount;

        require(
            token.transfer(msg.sender, releasableAmount),
            "TokenVesting: token transfer failed"
        );

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revoke(address _beneficiary) external onlyOwner {
        require(beneficiaries[_beneficiary], "TokenVesting: beneficiary does not exist");

        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.revocable, "TokenVesting: vesting schedule is not revocable");
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 releasableAmount = _releasableAmount(_beneficiary);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(_beneficiary, releasableAmount),
                "TokenVesting: token transfer to beneficiary failed"
            );
        }

        uint256 unreleased = schedule.totalAmount - schedule.releasedAmount;
        if (unreleased > 0) {
            require(
                token.transfer(owner, unreleased),
                "TokenVesting: token transfer to owner failed"
            );
        }

        schedule.revoked = true;
        totalVestedAmount -= unreleased;

        emit VestingRevoked(_beneficiary, unreleased);
        if (releasableAmount > 0) {
            emit TokensReleased(_beneficiary, releasableAmount);
        }
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "TokenVesting: new owner address cannot be zero");
        require(_newOwner != owner, "TokenVesting: new owner must be different from current owner");

        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function getVestingSchedule(address _beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool revoked
    ) {
        require(beneficiaries[_beneficiary], "TokenVesting: beneficiary does not exist");

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

    function releasableAmount(address _beneficiary) external view returns (uint256) {
        return _releasableAmount(_beneficiary);
    }

    function vestedAmount(address _beneficiary) external view returns (uint256) {
        return _vestedAmount(_beneficiary);
    }

    function _releasableAmount(address _beneficiary) private view returns (uint256) {
        return _vestedAmount(_beneficiary) - vestingSchedules[_beneficiary].releasedAmount;
    }

    function _vestedAmount(address _beneficiary) private view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (!beneficiaries[_beneficiary] || schedule.revoked) {
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

    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > totalVestedAmount, "TokenVesting: no excess tokens to withdraw");

        uint256 excessAmount = contractBalance - totalVestedAmount;
        require(
            token.transfer(owner, excessAmount),
            "TokenVesting: emergency withdrawal failed"
        );
    }
}
