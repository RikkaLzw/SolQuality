
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    uint256 public constant MIN_VESTING_DURATION = 30 days;
    uint256 public constant MAX_VESTING_DURATION = 1460 days;
    uint256 public constant PERCENTAGE_BASE = 10000;


    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }


    IERC20 private immutable _token;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256) private _vestingSchedulesCount;
    bytes32[] private _vestingScheduleIds;
    uint256 private _totalVestedAmount;


    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 duration
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


    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "TokenVesting: invalid address");
        _;
    }

    modifier onlyValidAmount(uint256 amount) {
        require(amount > 0, "TokenVesting: amount must be greater than 0");
        _;
    }

    modifier onlyValidDuration(uint256 duration) {
        require(
            duration >= MIN_VESTING_DURATION && duration <= MAX_VESTING_DURATION,
            "TokenVesting: invalid duration"
        );
        _;
    }

    modifier onlyExistingSchedule(bytes32 vestingScheduleId) {
        require(
            _vestingSchedules[vestingScheduleId].beneficiary != address(0),
            "TokenVesting: vesting schedule does not exist"
        );
        _;
    }

    modifier onlyBeneficiaryOrOwner(bytes32 vestingScheduleId) {
        require(
            msg.sender == _vestingSchedules[vestingScheduleId].beneficiary ||
            msg.sender == owner(),
            "TokenVesting: only beneficiary or owner"
        );
        _;
    }


    constructor(address token_) onlyValidAddress(token_) {
        _token = IERC20(token_);
    }


    function createVestingSchedule(
        address beneficiary_,
        uint256 totalAmount_,
        uint256 duration_,
        uint256 cliffDuration_,
        bool revocable_
    )
        external
        onlyOwner
        onlyValidAddress(beneficiary_)
        onlyValidAmount(totalAmount_)
        onlyValidDuration(duration_)
    {
        require(cliffDuration_ <= duration_, "TokenVesting: cliff duration exceeds total duration");
        require(
            _getAvailableTokens() >= totalAmount_,
            "TokenVesting: insufficient tokens available"
        );

        bytes32 vestingScheduleId = _generateVestingScheduleId(beneficiary_);

        _vestingSchedules[vestingScheduleId] = VestingSchedule({
            beneficiary: beneficiary_,
            totalAmount: totalAmount_,
            releasedAmount: 0,
            startTime: block.timestamp,
            duration: duration_,
            cliffDuration: cliffDuration_,
            revocable: revocable_,
            revoked: false
        });

        _vestingScheduleIds.push(vestingScheduleId);
        _vestingSchedulesCount[beneficiary_] = _vestingSchedulesCount[beneficiary_].add(1);
        _totalVestedAmount = _totalVestedAmount.add(totalAmount_);

        emit VestingScheduleCreated(vestingScheduleId, beneficiary_, totalAmount_, duration_);
    }


    function release(bytes32 vestingScheduleId)
        external
        nonReentrant
        onlyExistingSchedule(vestingScheduleId)
        onlyBeneficiaryOrOwner(vestingScheduleId)
    {
        VestingSchedule storage schedule = _vestingSchedules[vestingScheduleId];
        require(!schedule.revoked, "TokenVesting: vesting schedule revoked");

        uint256 releasableAmount = _computeReleasableAmount(schedule);
        require(releasableAmount > 0, "TokenVesting: no tokens available for release");

        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        _token.safeTransfer(schedule.beneficiary, releasableAmount);

        emit TokensReleased(vestingScheduleId, schedule.beneficiary, releasableAmount);
    }


    function revoke(bytes32 vestingScheduleId)
        external
        onlyOwner
        onlyExistingSchedule(vestingScheduleId)
    {
        VestingSchedule storage schedule = _vestingSchedules[vestingScheduleId];
        require(schedule.revocable, "TokenVesting: vesting schedule not revocable");
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 vestedAmount = _computeReleasableAmount(schedule);
        uint256 unvestedAmount = schedule.totalAmount.sub(schedule.releasedAmount).sub(vestedAmount);

        schedule.revoked = true;
        _totalVestedAmount = _totalVestedAmount.sub(unvestedAmount);

        if (vestedAmount > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(vestedAmount);
            _token.safeTransfer(schedule.beneficiary, vestedAmount);
        }

        emit VestingScheduleRevoked(vestingScheduleId, schedule.beneficiary, unvestedAmount);
    }


    function withdrawExcessTokens(uint256 amount)
        external
        onlyOwner
        onlyValidAmount(amount)
    {
        require(amount <= _getAvailableTokens(), "TokenVesting: insufficient available tokens");
        _token.safeTransfer(owner(), amount);
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 availableTokens = _getAvailableTokens();
        if (availableTokens > 0) {
            _token.safeTransfer(owner(), availableTokens);
        }
    }


    function getToken() external view returns (address) {
        return address(_token);
    }

    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return _vestingSchedules[vestingScheduleId];
    }

    function getVestingSchedulesCount() external view returns (uint256) {
        return _vestingScheduleIds.length;
    }

    function getVestingSchedulesCountByBeneficiary(address beneficiary)
        external
        view
        returns (uint256)
    {
        return _vestingSchedulesCount[beneficiary];
    }

    function getVestingScheduleIdAtIndex(uint256 index)
        external
        view
        returns (bytes32)
    {
        require(index < _vestingScheduleIds.length, "TokenVesting: index out of bounds");
        return _vestingScheduleIds[index];
    }

    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        onlyExistingSchedule(vestingScheduleId)
        returns (uint256)
    {
        return _computeReleasableAmount(_vestingSchedules[vestingScheduleId]);
    }

    function getTotalVestedAmount() external view returns (uint256) {
        return _totalVestedAmount;
    }

    function getAvailableTokens() external view returns (uint256) {
        return _getAvailableTokens();
    }


    function _computeReleasableAmount(VestingSchedule memory schedule)
        internal
        view
        returns (uint256)
    {
        if (schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;


        if (currentTime < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }


        if (currentTime >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount.sub(schedule.releasedAmount);
        }


        uint256 timeElapsed = currentTime.sub(schedule.startTime);
        uint256 vestedAmount = schedule.totalAmount.mul(timeElapsed).div(schedule.duration);

        return vestedAmount.sub(schedule.releasedAmount);
    }

    function _generateVestingScheduleId(address beneficiary)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                beneficiary,
                block.timestamp,
                _vestingSchedulesCount[beneficiary]
            )
        );
    }

    function _getAvailableTokens() internal view returns (uint256) {
        uint256 contractBalance = _token.balanceOf(address(this));
        return contractBalance.sub(_totalVestedAmount);
    }
}
