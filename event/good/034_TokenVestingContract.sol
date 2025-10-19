
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
    bytes32[] public vestingScheduleIds;

    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensReleased(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed vestingScheduleId,
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

    modifier vestingScheduleExists(bytes32 vestingScheduleId) {
        require(
            vestingSchedules[vestingScheduleId].beneficiary != address(0),
            "TokenVesting: vesting schedule does not exist"
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
    ) external onlyOwner {
        require(_beneficiary != address(0), "TokenVesting: beneficiary cannot be zero address");
        require(_totalAmount > 0, "TokenVesting: total amount must be greater than zero");
        require(_vestingDuration > 0, "TokenVesting: vesting duration must be greater than zero");
        require(_cliffDuration <= _vestingDuration, "TokenVesting: cliff duration cannot exceed vesting duration");

        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(availableBalance >= _totalAmount, "TokenVesting: insufficient token balance");

        bytes32 vestingScheduleId = keccak256(
            abi.encodePacked(_beneficiary, _totalAmount, _startTime, block.timestamp, vestingScheduleCount[_beneficiary])
        );

        vestingSchedules[vestingScheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });

        vestingScheduleIds.push(vestingScheduleId);
        vestingScheduleCount[_beneficiary]++;
        totalVestedAmount += _totalAmount;

        emit VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );
    }

    function release(bytes32 vestingScheduleId) external vestingScheduleExists(vestingScheduleId) {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];

        require(!schedule.revoked, "TokenVesting: vesting schedule has been revoked");
        require(
            msg.sender == schedule.beneficiary || msg.sender == owner,
            "TokenVesting: only beneficiary or owner can release tokens"
        );

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        require(releasableAmount > 0, "TokenVesting: no tokens available for release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(
            token.transfer(schedule.beneficiary, releasableAmount),
            "TokenVesting: token transfer failed"
        );

        emit TokensReleased(vestingScheduleId, schedule.beneficiary, releasableAmount);
    }

    function revoke(bytes32 vestingScheduleId) external onlyOwner vestingScheduleExists(vestingScheduleId) {
        VestingSchedule storage schedule = vestingSchedules[vestingScheduleId];

        require(schedule.revocable, "TokenVesting: vesting schedule is not revocable");
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 vestedAmount = _computeVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(schedule.beneficiary, releasableAmount),
                "TokenVesting: token transfer failed"
            );
            emit TokensReleased(vestingScheduleId, schedule.beneficiary, releasableAmount);
        }

        emit VestingScheduleRevoked(vestingScheduleId, schedule.beneficiary, unvestedAmount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(amount <= availableBalance, "TokenVesting: insufficient available balance");
        require(token.transfer(owner, amount), "TokenVesting: token transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TokenVesting: new owner cannot be zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        vestingScheduleExists(vestingScheduleId)
        returns (VestingSchedule memory)
    {
        return vestingSchedules[vestingScheduleId];
    }

    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        vestingScheduleExists(vestingScheduleId)
        returns (uint256)
    {
        return _computeReleasableAmount(vestingSchedules[vestingScheduleId]);
    }

    function computeVestedAmount(bytes32 vestingScheduleId)
        external
        view
        vestingScheduleExists(vestingScheduleId)
        returns (uint256)
    {
        return _computeVestedAmount(vestingSchedules[vestingScheduleId]);
    }

    function getVestingScheduleCount() external view returns (uint256) {
        return vestingScheduleIds.length;
    }

    function getVestingScheduleIdAtIndex(uint256 index) external view returns (bytes32) {
        require(index < vestingScheduleIds.length, "TokenVesting: index out of bounds");
        return vestingScheduleIds[index];
    }

    function _computeReleasableAmount(VestingSchedule memory schedule)
        private
        view
        returns (uint256)
    {
        if (schedule.revoked) {
            return 0;
        }
        return _computeVestedAmount(schedule) - schedule.releasedAmount;
    }

    function _computeVestedAmount(VestingSchedule memory schedule)
        private
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.startTime + schedule.cliffDuration) {
            return 0;
        } else if (currentTime >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime - schedule.startTime;
            return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        }
    }
}
