
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
    uint256 private constant BASIS_POINTS = 10000;


    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revoked;
        bool initialized;
    }


    IERC20 private immutable _token;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => uint256) private _vestingScheduleCount;
    bytes32[] private _vestingScheduleIds;
    uint256 private _totalVestedAmount;


    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensClaimed(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 unvestedAmount
    );


    modifier onlyValidSchedule(bytes32 scheduleId) {
        require(_vestingSchedules[scheduleId].initialized, "Vesting schedule not found");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(
            _vestingSchedules[scheduleId].beneficiary == msg.sender,
            "Only beneficiary can perform this action"
        );
        _;
    }

    modifier notRevoked(bytes32 scheduleId) {
        require(!_vestingSchedules[scheduleId].revoked, "Vesting schedule is revoked");
        _;
    }


    constructor(address token_) {
        require(token_ != address(0), "Token address cannot be zero");
        _token = IERC20(token_);
    }


    function createVestingSchedule(
        address beneficiary_,
        uint256 amount_,
        uint256 startTime_,
        uint256 cliffDuration_,
        uint256 vestingDuration_
    ) external onlyOwner {
        _validateVestingParameters(beneficiary_, amount_, startTime_, cliffDuration_, vestingDuration_);

        require(
            _token.balanceOf(address(this)) >= _totalVestedAmount.add(amount_),
            "Insufficient contract balance"
        );

        bytes32 scheduleId = _generateScheduleId(beneficiary_, _vestingScheduleCount[beneficiary_]);

        _vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary_,
            totalAmount: amount_,
            claimedAmount: 0,
            startTime: startTime_,
            cliffDuration: cliffDuration_,
            vestingDuration: vestingDuration_,
            revoked: false,
            initialized: true
        });

        _vestingScheduleIds.push(scheduleId);
        _vestingScheduleCount[beneficiary_] = _vestingScheduleCount[beneficiary_].add(1);
        _totalVestedAmount = _totalVestedAmount.add(amount_);

        emit VestingScheduleCreated(
            scheduleId,
            beneficiary_,
            amount_,
            startTime_,
            cliffDuration_,
            vestingDuration_
        );
    }


    function claimTokens(bytes32 scheduleId)
        external
        nonReentrant
        onlyValidSchedule(scheduleId)
        onlyBeneficiary(scheduleId)
        notRevoked(scheduleId)
    {
        uint256 claimableAmount = _getClaimableAmount(scheduleId);
        require(claimableAmount > 0, "No tokens available for claim");

        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        schedule.claimedAmount = schedule.claimedAmount.add(claimableAmount);

        _token.safeTransfer(schedule.beneficiary, claimableAmount);

        emit TokensClaimed(scheduleId, schedule.beneficiary, claimableAmount);
    }


    function revokeVestingSchedule(bytes32 scheduleId)
        external
        onlyOwner
        onlyValidSchedule(scheduleId)
        notRevoked(scheduleId)
    {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];

        uint256 claimableAmount = _getClaimableAmount(scheduleId);
        if (claimableAmount > 0) {
            schedule.claimedAmount = schedule.claimedAmount.add(claimableAmount);
            _token.safeTransfer(schedule.beneficiary, claimableAmount);
        }

        uint256 unvestedAmount = schedule.totalAmount.sub(schedule.claimedAmount);
        schedule.revoked = true;
        _totalVestedAmount = _totalVestedAmount.sub(unvestedAmount);

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);
    }


    function withdrawExcessTokens(uint256 amount) external onlyOwner {
        uint256 availableBalance = _token.balanceOf(address(this)).sub(_totalVestedAmount);
        require(amount <= availableBalance, "Insufficient excess balance");

        _token.safeTransfer(owner(), amount);
    }


    function getClaimableAmount(bytes32 scheduleId)
        external
        view
        onlyValidSchedule(scheduleId)
        returns (uint256)
    {
        return _getClaimableAmount(scheduleId);
    }


    function getVestingSchedule(bytes32 scheduleId)
        external
        view
        onlyValidSchedule(scheduleId)
        returns (VestingSchedule memory)
    {
        return _vestingSchedules[scheduleId];
    }


    function getVestingScheduleCount(address beneficiary) external view returns (uint256) {
        return _vestingScheduleCount[beneficiary];
    }


    function getTotalVestingScheduleCount() external view returns (uint256) {
        return _vestingScheduleIds.length;
    }


    function getToken() external view returns (address) {
        return address(_token);
    }


    function getTotalVestedAmount() external view returns (uint256) {
        return _totalVestedAmount;
    }


    function _validateVestingParameters(
        address beneficiary_,
        uint256 amount_,
        uint256 startTime_,
        uint256 cliffDuration_,
        uint256 vestingDuration_
    ) private view {
        require(beneficiary_ != address(0), "Beneficiary cannot be zero address");
        require(amount_ > 0, "Amount must be greater than zero");
        require(startTime_ >= block.timestamp, "Start time cannot be in the past");
        require(vestingDuration_ > 0, "Vesting duration must be greater than zero");
        require(cliffDuration_ <= vestingDuration_, "Cliff duration cannot exceed vesting duration");
    }


    function _getClaimableAmount(bytes32 scheduleId) private view returns (uint256) {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];

        if (schedule.revoked || block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount.sub(schedule.claimedAmount);
    }


    function _calculateVestedAmount(VestingSchedule memory schedule) private view returns (uint256) {
        if (block.timestamp >= schedule.startTime.add(schedule.vestingDuration)) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        return schedule.totalAmount.mul(timeFromStart).div(schedule.vestingDuration);
    }


    function _generateScheduleId(address beneficiary, uint256 index) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, index));
    }
}
