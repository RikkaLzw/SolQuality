
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;


    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant MAX_VESTING_DURATION = 365 * 5;
    uint256 public constant MIN_VESTING_DURATION = 30;


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
        require(_vestingSchedules[vestingScheduleId].initialized, "VestingSchedule does not exist");
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(!_vestingSchedules[vestingScheduleId].revoked, "VestingSchedule is revoked");
        _;
    }

    modifier validDuration(uint256 duration) {
        require(
            duration >= MIN_VESTING_DURATION && duration <= MAX_VESTING_DURATION,
            "Invalid vesting duration"
        );
        _;
    }


    constructor(address token_) {
        require(token_ != address(0), "Token address cannot be zero");
        _token = IERC20(token_);
    }


    function createVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 slicePeriodSeconds,
        bool revocable,
        uint256 amount
    ) external onlyOwner validDuration(duration / SECONDS_PER_DAY) {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(duration >= cliff, "Duration must be >= cliff");
        require(slicePeriodSeconds >= 1, "Slice period must be >= 1 second");
        require(slicePeriodSeconds <= duration, "Slice period must be <= duration");
        require(_getWithdrawableAmount() >= amount, "Insufficient tokens available");

        bytes32 vestingScheduleId = _computeNextVestingScheduleIdForHolder(beneficiary);

        _vestingSchedules[vestingScheduleId] = VestingSchedule({
            initialized: true,
            beneficiary: beneficiary,
            cliff: start + cliff,
            start: start,
            duration: duration,
            slicePeriodSeconds: slicePeriodSeconds,
            revocable: revocable,
            amountTotal: amount,
            released: 0,
            revoked: false
        });

        _vestingSchedulesTotalAmount += amount;
        _vestingSchedulesIds.push(vestingScheduleId);
        _holdersVestingCount[beneficiary]++;

        emit VestingScheduleCreated(vestingScheduleId, beneficiary, amount);
    }


    function revoke(bytes32 vestingScheduleId)
        external
        onlyOwner
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable, "VestingSchedule is not revocable");

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            _release(vestingScheduleId, vestedAmount);
        }

        uint256 unreleased = vestingSchedule.amountTotal - vestingSchedule.released;
        _vestingSchedulesTotalAmount -= unreleased;
        vestingSchedule.revoked = true;

        emit VestingScheduleRevoked(vestingScheduleId, vestingSchedule.beneficiary, unreleased);
    }


    function release(bytes32 vestingScheduleId, uint256 amount)
        external
        nonReentrant
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];

        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(isBeneficiary || isOwner, "Only beneficiary or owner can release tokens");

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= amount, "Cannot release more than vested amount");

        _release(vestingScheduleId, amount);
    }


    function withdraw(uint256 amount) external onlyOwner {
        require(_getWithdrawableAmount() >= amount, "Insufficient withdrawable funds");
        _token.safeTransfer(owner(), amount);
    }


    function getVestingSchedulesCountByBeneficiary(address beneficiary)
        external
        view
        returns (uint256)
    {
        return _holdersVestingCount[beneficiary];
    }


    function getVestingIdAtIndex(address beneficiary, uint256 index)
        external
        view
        returns (bytes32)
    {
        return _computeVestingScheduleIdForAddressAndIndex(beneficiary, index);
    }


    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return _vestingSchedules[vestingScheduleId];
    }


    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        returns (uint256)
    {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }


    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return _vestingSchedulesTotalAmount;
    }


    function getToken() external view returns (address) {
        return address(_token);
    }


    function _release(bytes32 vestingScheduleId, uint256 amount) internal {
        VestingSchedule storage vestingSchedule = _vestingSchedules[vestingScheduleId];

        vestingSchedule.released += amount;
        _vestingSchedulesTotalAmount -= amount;

        _token.safeTransfer(vestingSchedule.beneficiary, amount);

        emit TokensReleased(vestingScheduleId, vestingSchedule.beneficiary, amount);
    }


    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        uint256 currentTime = _getCurrentTime();
        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked) {
            return 0;
        } else if (currentTime >= vestingSchedule.start + vestingSchedule.duration) {
            return vestingSchedule.amountTotal - vestingSchedule.released;
        } else {
            uint256 timeFromStart = currentTime - vestingSchedule.start;
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            uint256 vestedAmount = (vestingSchedule.amountTotal * vestedSeconds) / vestingSchedule.duration;
            return vestedAmount - vestingSchedule.released;
        }
    }


    function _computeNextVestingScheduleIdForHolder(address holder) internal view returns (bytes32) {
        return _computeVestingScheduleIdForAddressAndIndex(holder, _holdersVestingCount[holder]);
    }


    function _computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(holder, index));
    }


    function _getWithdrawableAmount() internal view returns (uint256) {
        return _token.balanceOf(address(this)) - _vestingSchedulesTotalAmount;
    }


    function _getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
