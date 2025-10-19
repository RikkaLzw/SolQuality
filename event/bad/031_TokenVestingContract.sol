
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
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public token;
    address public owner;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;
    uint256 public totalVestedAmount;


    event VestingScheduleCreated(address beneficiary, uint256 amount, uint256 startTime, uint256 duration);
    event TokensReleased(address beneficiary, uint256 amount);
    event VestingRevoked(address beneficiary);


    error Err1();
    error Err2();
    error Err3();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validBeneficiary(address _beneficiary) {
        require(_beneficiary != address(0));
        _;
    }

    constructor(address _token) {
        require(_token != address(0));
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration,
        bool _revocable
    ) external onlyOwner validBeneficiary(_beneficiary) {
        require(_totalAmount > 0);
        require(_duration > 0);
        require(_cliffDuration <= _duration);
        require(vestingSchedules[_beneficiary].totalAmount == 0);

        if (_startTime == 0) {
            revert Err1();
        }

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            duration: _duration,
            cliffDuration: _cliffDuration,
            revocable: _revocable,
            revoked: false
        });

        beneficiaries[_beneficiary] = true;
        totalVestedAmount += _totalAmount;

        require(token.transferFrom(msg.sender, address(this), _totalAmount));

        emit VestingScheduleCreated(_beneficiary, _totalAmount, _startTime, _duration);

    }

    function release() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0);
        require(!schedule.revoked);

        uint256 releasableAmount = getReleasableAmount(msg.sender);
        require(releasableAmount > 0);

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(msg.sender, releasableAmount));

        emit TokensReleased(msg.sender, releasableAmount);

    }

    function revokeVesting(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.revocable);
        require(!schedule.revoked);

        uint256 releasableAmount = getReleasableAmount(_beneficiary);
        uint256 refundAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(_beneficiary, releasableAmount));
        }

        schedule.revoked = true;
        totalVestedAmount -= (schedule.totalAmount - schedule.releasedAmount);

        if (refundAmount > 0) {
            require(token.transfer(owner, refundAmount));
        }

        emit VestingRevoked(_beneficiary);

    }

    function getReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;

        return vestedAmount - schedule.releasedAmount;
    }

    function getVestingSchedule(address _beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.cliffDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function withdrawExcessTokens() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > totalVestedAmount);

        uint256 excessAmount = contractBalance - totalVestedAmount;
        require(token.transfer(owner, excessAmount));


    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;

    }

    function emergencyPause() external onlyOwner {
        if (totalVestedAmount == 0) {
            revert Err2();
        }


    }
}
