
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
        bool revoked;
    }

    IERC20 public token;
    address public owner;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    error Err1();
    error Err2();
    error Err3();

    event VestingCreated(address beneficiary, uint256 amount, uint256 startTime, uint256 duration);
    event TokensReleased(address beneficiary, uint256 amount);
    event VestingRevoked(address beneficiary);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliffDuration
    ) external onlyOwner {
        require(_beneficiary != address(0));
        require(_amount > 0);
        require(_duration > 0);
        require(_cliffDuration <= _duration);
        require(vestingSchedules[_beneficiary].totalAmount == 0);

        token.transferFrom(msg.sender, address(this), _amount);

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: _startTime,
            duration: _duration,
            cliffDuration: _cliffDuration,
            revoked: false
        });

        beneficiaries[_beneficiary] = true;

        emit VestingCreated(_beneficiary, _amount, _startTime, _duration);
    }

    function release() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0);
        require(!schedule.revoked);

        uint256 releasableAmount = _releasableAmount(msg.sender);
        require(releasableAmount > 0);

        schedule.releasedAmount += releasableAmount;
        token.transfer(msg.sender, releasableAmount);

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(schedule.totalAmount > 0);
        require(!schedule.revoked);

        uint256 releasableAmount = _releasableAmount(_beneficiary);
        uint256 refundAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            token.transfer(_beneficiary, releasableAmount);
        }

        if (refundAmount > 0) {
            token.transfer(owner, refundAmount);
        }

        schedule.revoked = true;

        emit VestingRevoked(_beneficiary);
    }

    function _releasableAmount(address _beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

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
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.cliffDuration,
            schedule.revoked
        );
    }

    function releasableAmount(address _beneficiary) external view returns (uint256) {
        return _releasableAmount(_beneficiary);
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }
}
