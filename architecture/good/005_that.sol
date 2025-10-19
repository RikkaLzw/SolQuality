
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant MAX_VESTING_DURATION = 365 * 5 * SECONDS_PER_DAY;
    uint256 private constant MIN_VESTING_DURATION = 30 * SECONDS_PER_DAY;


    struct VestingSchedule {
        bool initialized;
        address beneficiary;
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 slicePeriodSeconds;
        bool revocable;
        uint256 amountTotal;
        uint256 released;
        bool revoked;
    }


    IERC20 private immutable _token;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256) private _holdersVestingCount;
    bytes32[] private _vestingSchedulesIds;
    uint256 private _vestingSchedulesTotalAmount;


    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 cliff,
        uint256 start,
        uint256 duration,
        uint256 slicePeriodSeconds,
        bool revocable,
        uint256 amount
    );

    event TokensReleased(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 unreleased
    );


    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(_vestingSchedules[vestingScheduleId].initialized, "VestingContract: vesting schedule does not exist");
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(!_vestingSchedules[vestingScheduleId].revoked, "VestingContract: vesting schedule is revoked");
        _;
    }

    modifier onlyBeneficiary(bytes32 vestingScheduleId) {
        require(
            msg.sender == _vestingSchedules[vestingScheduleId].beneficiary ||
            msg.sender == owner(),
            "VestingContract: only beneficiary or owner can release tokens"
        );
        _;
    }

    modifier validVestingParams(
        uint256 _cliff,
        uint256 _start,
        uint256 _duration,
        uint256 _slicePeriodSeconds
    ) {
        require(_duration >= MIN_VESTING_DURATION, "VestingContract: duration too short");
        require(_duration <= MAX_VESTING_DURATION, "VestingContract: duration too long");
        require(_slicePeriodSeconds >= 1, "VestingContract: slice period must be at least 1 second");
        require(_cliff <= _duration, "VestingContract: cliff cannot be longer than duration");
        require(_start.add(_duration) > block.timestamp, "VestingContract: final time must be in the future");
        _;
    }


    constructor(address token_) {
        require(token_ != address(0), "VestingContract: token address cannot be zero");
        _token = IERC20(token_);
    }


    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    ) external onlyOwner validVestingParams(_cliff, _start, _duration, _slicePeriodSeconds) {
        require(_beneficiary != address(0), "VestingContract: beneficiary cannot be zero address");
        require(_amount > 0, "VestingContract: amount must be greater than 0");
        require(
            getWithdrawableAmount() >= _amount,
            "VestingContract: insufficient tokens for vesting schedule"
        );

        bytes32 vestingScheduleId = _computeNextVestingScheduleIdForHolder(_beneficiary);
        uint256 cliff = _start.add(_cliff);

        _vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            0,
            false
        );

        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.add(_amount);
        _vestingSchedulesIds.push(vestingScheduleId);
        _holdersVestingCount[_beneficiary] = _holdersVestingCount[_beneficiary].add(1);

        emit VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount
        );
    }


    function revoke(bytes32 vestingScheduleId)
        external
        onlyOwner
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable, "VestingContract: vesting is not revocable");

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            _release(vestingScheduleId, vestedAmount);
        }

        uint256 unreleased = vestingSchedule.amountTotal.sub(vestingSchedule.released);
        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.sub(unreleased);
        vestingSchedule.revoked = true;

        emit VestingScheduleRevoked(vestingScheduleId, vestingSchedule.beneficiary, unreleased);
    }


    function release(bytes32 vestingScheduleId, uint256 amount)
        external
        nonReentrant
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        onlyBeneficiary(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule);
        require(amount <= releasableAmount, "VestingContract: cannot release more than releasable amount");
        _release(vestingScheduleId, amount);
    }


    function withdraw(uint256 amount) external onlyOwner {
        require(
            getWithdrawableAmount() >= amount,
            "VestingContract: not enough withdrawable funds"
        );
        _token.safeTransfer(owner(), amount);
    }


    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return _holdersVestingCount[_beneficiary];
    }


    function getVestingIdAtIndex(address _beneficiary, uint256 _index)
        external
        view
        returns (bytes32)
    {
        return _computeVestingScheduleIdForAddressAndIndex(_beneficiary, _index);
    }


    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return _vestingSchedules[vestingScheduleId];
    }


    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)).sub(_vestingSchedulesTotalAmount);
    }


    function _computeNextVestingScheduleIdForHolder(address holder)
        private
        view
        returns (bytes32)
    {
        return _computeVestingScheduleIdForAddressAndIndex(holder, _holdersVestingCount[holder]);
    }


    function _computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(holder, index));
    }


    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        private
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;
        if (currentTime < vestingSchedule.cliff) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(vestedSeconds).div(vestingSchedule.duration);
            return vestedAmount.sub(vestingSchedule.released);
        }
    }


    function _release(bytes32 vestingScheduleId, uint256 amount) private {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        vestingSchedule.released = vestingSchedule.released.add(amount);
        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.sub(amount);
        _token.safeTransfer(vestingSchedule.beneficiary, amount);

        emit TokensReleased(vestingScheduleId, vestingSchedule.beneficiary, amount);
    }


    function getToken() external view returns (address) {
        return address(_token);
    }


    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return _vestingSchedulesTotalAmount;
    }


    function getVestingSchedulesCount() external view returns (uint256) {
        return _vestingSchedulesIds.length;
    }
}
