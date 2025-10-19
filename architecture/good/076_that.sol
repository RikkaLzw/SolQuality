
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    uint256 private constant PERCENTAGE_BASE = 10000;
    uint256 private constant MIN_VESTING_DURATION = 1 days;
    uint256 private constant MAX_VESTING_DURATION = 10 * 365 days;


    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        bool revocable;
        bool revoked;
    }


    IERC20 public immutable token;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    mapping(address => uint256) private beneficiaryVestingCount;
    mapping(address => bytes32[]) private beneficiaryScheduleIds;

    bytes32[] private vestingScheduleIds;
    uint256 private totalVestedAmount;
    bool private vestingEnabled;


    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliff,
        uint256 duration
    );

    event TokensReleased(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(bytes32 indexed scheduleId, address indexed beneficiary);
    event VestingStatusChanged(bool enabled);
    event EmergencyWithdraw(address indexed token, uint256 amount);


    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyValidAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier onlyValidDuration(uint256 _duration) {
        require(
            _duration >= MIN_VESTING_DURATION && _duration <= MAX_VESTING_DURATION,
            "Invalid vesting duration"
        );
        _;
    }

    modifier onlyWhenVestingEnabled() {
        require(vestingEnabled, "Vesting is disabled");
        _;
    }

    modifier onlyExistingSchedule(bytes32 _scheduleId) {
        require(vestingSchedules[_scheduleId].beneficiary != address(0), "Schedule does not exist");
        _;
    }

    modifier onlyNotRevoked(bytes32 _scheduleId) {
        require(!vestingSchedules[_scheduleId].revoked, "Schedule is revoked");
        _;
    }


    constructor(address _token) onlyValidAddress(_token) {
        token = IERC20(_token);
        vestingEnabled = true;
    }


    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _cliff,
        uint256 _duration,
        bool _revocable
    )
        external
        onlyOwner
        onlyWhenVestingEnabled
        onlyValidAddress(_beneficiary)
        onlyValidAmount(_amount)
        onlyValidDuration(_duration)
        nonReentrant
    {
        require(_startTime >= block.timestamp, "Start time cannot be in the past");
        require(_cliff <= _duration, "Cliff cannot be longer than duration");
        require(
            token.balanceOf(address(this)) >= totalVestedAmount.add(_amount),
            "Insufficient contract balance"
        );

        bytes32 scheduleId = _generateScheduleId(_beneficiary, _amount, _startTime);
        require(vestingSchedules[scheduleId].beneficiary == address(0), "Schedule already exists");

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: _startTime,
            cliff: _cliff,
            duration: _duration,
            revocable: _revocable,
            revoked: false
        });

        vestingScheduleIds.push(scheduleId);
        beneficiaryScheduleIds[_beneficiary].push(scheduleId);
        beneficiaryVestingCount[_beneficiary] = beneficiaryVestingCount[_beneficiary].add(1);
        totalVestedAmount = totalVestedAmount.add(_amount);

        emit VestingScheduleCreated(scheduleId, _beneficiary, _amount, _startTime, _cliff, _duration);
    }


    function release(bytes32 _scheduleId)
        external
        onlyExistingSchedule(_scheduleId)
        onlyNotRevoked(_scheduleId)
        nonReentrant
    {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(
            msg.sender == schedule.beneficiary || msg.sender == owner(),
            "Not authorized to release tokens"
        );

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        totalVestedAmount = totalVestedAmount.sub(releasableAmount);

        token.safeTransfer(schedule.beneficiary, releasableAmount);

        emit TokensReleased(_scheduleId, schedule.beneficiary, releasableAmount);
    }


    function revoke(bytes32 _scheduleId)
        external
        onlyOwner
        onlyExistingSchedule(_scheduleId)
        onlyNotRevoked(_scheduleId)
        nonReentrant
    {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.revocable, "Schedule is not revocable");

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        uint256 refundAmount = schedule.totalAmount.sub(schedule.releasedAmount).sub(releasableAmount);

        if (releasableAmount > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
            token.safeTransfer(schedule.beneficiary, releasableAmount);
            emit TokensReleased(_scheduleId, schedule.beneficiary, releasableAmount);
        }

        schedule.revoked = true;
        totalVestedAmount = totalVestedAmount.sub(refundAmount);

        emit VestingRevoked(_scheduleId, schedule.beneficiary);
    }


    function batchRelease(bytes32[] calldata _scheduleIds) external nonReentrant {
        for (uint256 i = 0; i < _scheduleIds.length; i++) {
            bytes32 scheduleId = _scheduleIds[i];
            VestingSchedule storage schedule = vestingSchedules[scheduleId];

            if (schedule.beneficiary == address(0) || schedule.revoked) {
                continue;
            }

            if (msg.sender != schedule.beneficiary && msg.sender != owner()) {
                continue;
            }

            uint256 releasableAmount = _computeReleasableAmount(schedule);
            if (releasableAmount > 0) {
                schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
                totalVestedAmount = totalVestedAmount.sub(releasableAmount);
                token.safeTransfer(schedule.beneficiary, releasableAmount);
                emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
            }
        }
    }


    function setVestingEnabled(bool _enabled) external onlyOwner {
        vestingEnabled = _enabled;
        emit VestingStatusChanged(_enabled);
    }


    function emergencyWithdraw(address _token, uint256 _amount)
        external
        onlyOwner
        onlyValidAddress(_token)
        onlyValidAmount(_amount)
        nonReentrant
    {
        IERC20(_token).safeTransfer(owner(), _amount);
        emit EmergencyWithdraw(_token, _amount);
    }


    function getVestingSchedule(bytes32 _scheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[_scheduleId];
    }

    function getReleasableAmount(bytes32 _scheduleId) external view returns (uint256) {
        return _computeReleasableAmount(vestingSchedules[_scheduleId]);
    }

    function getBeneficiarySchedules(address _beneficiary)
        external
        view
        returns (bytes32[] memory)
    {
        return beneficiaryScheduleIds[_beneficiary];
    }

    function getTotalVestedAmount() external view returns (uint256) {
        return totalVestedAmount;
    }

    function getVestingScheduleCount() external view returns (uint256) {
        return vestingScheduleIds.length;
    }

    function isVestingEnabled() external view returns (bool) {
        return vestingEnabled;
    }


    function _computeReleasableAmount(VestingSchedule memory schedule)
        internal
        view
        returns (uint256)
    {
        if (schedule.revoked || block.timestamp < schedule.startTime.add(schedule.cliff)) {
            return 0;
        }

        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        uint256 vestedAmount;

        if (timeFromStart >= schedule.duration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount = schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
        }

        return vestedAmount.sub(schedule.releasedAmount);
    }

    function _generateScheduleId(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _beneficiary,
                _amount,
                _startTime,
                beneficiaryVestingCount[_beneficiary],
                block.timestamp
            )
        );
    }
}
