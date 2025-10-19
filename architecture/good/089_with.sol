
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;


    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;
    uint256 public constant MIN_CLIFF_DURATION = 30 days;
    uint256 public constant MAX_VESTING_DURATION = 1460 days;
    uint256 public constant MIN_VESTING_DURATION = 30 days;


    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 initialReleasePercentage;
        bool revoked;
        bool exists;
    }


    IERC20 public immutable token;
    mapping(bytes32 => VestingSchedule) private _vestingSchedules;
    mapping(address => bytes32[]) private _beneficiarySchedules;
    bytes32[] private _allScheduleIds;
    uint256 public totalVestedAmount;
    uint256 public totalClaimedAmount;


    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 initialReleasePercentage
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
        require(_vestingSchedules[scheduleId].exists, "Vesting schedule does not exist");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(
            _vestingSchedules[scheduleId].beneficiary == msg.sender,
            "Only beneficiary can perform this action"
        );
        _;
    }

    modifier onlyNonRevoked(bytes32 scheduleId) {
        require(
            !_vestingSchedules[scheduleId].revoked,
            "Vesting schedule has been revoked"
        );
        _;
    }

    modifier validVestingParams(
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 initialReleasePercentage
    ) {
        require(cliffDuration >= MIN_CLIFF_DURATION, "Cliff duration too short");
        require(
            vestingDuration >= MIN_VESTING_DURATION && vestingDuration <= MAX_VESTING_DURATION,
            "Invalid vesting duration"
        );
        require(cliffDuration <= vestingDuration, "Cliff duration cannot exceed vesting duration");
        require(
            initialReleasePercentage <= PERCENTAGE_DENOMINATOR,
            "Initial release percentage cannot exceed 100%"
        );
        _;
    }


    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = _token;
    }


    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 initialReleasePercentage
    )
        external
        onlyOwner
        whenNotPaused
        validVestingParams(cliffDuration, vestingDuration, initialReleasePercentage)
        returns (bytes32)
    {
        require(beneficiary != address(0), "Beneficiary address cannot be zero");
        require(totalAmount > 0, "Total amount must be greater than zero");
        require(startTime >= block.timestamp, "Start time cannot be in the past");


        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableTokens = contractBalance - (totalVestedAmount - totalClaimedAmount);
        require(availableTokens >= totalAmount, "Insufficient contract token balance");

        bytes32 scheduleId = _generateScheduleId(beneficiary, totalAmount, startTime);
        require(!_vestingSchedules[scheduleId].exists, "Vesting schedule already exists");

        _vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            initialReleasePercentage: initialReleasePercentage,
            revoked: false,
            exists: true
        });

        _beneficiarySchedules[beneficiary].push(scheduleId);
        _allScheduleIds.push(scheduleId);
        totalVestedAmount += totalAmount;

        emit VestingScheduleCreated(
            scheduleId,
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            initialReleasePercentage
        );

        return scheduleId;
    }


    function claimTokens(bytes32 scheduleId)
        external
        nonReentrant
        whenNotPaused
        onlyValidSchedule(scheduleId)
        onlyBeneficiary(scheduleId)
        onlyNonRevoked(scheduleId)
    {
        uint256 claimableAmount = _getClaimableAmount(scheduleId);
        require(claimableAmount > 0, "No tokens available for claim");

        VestingSchedule storage schedule = _vestingSchedules[scheduleId];
        schedule.claimedAmount += claimableAmount;
        totalClaimedAmount += claimableAmount;

        token.safeTransfer(schedule.beneficiary, claimableAmount);

        emit TokensClaimed(scheduleId, schedule.beneficiary, claimableAmount);
    }


    function revokeVestingSchedule(bytes32 scheduleId)
        external
        onlyOwner
        onlyValidSchedule(scheduleId)
        onlyNonRevoked(scheduleId)
    {
        VestingSchedule storage schedule = _vestingSchedules[scheduleId];

        uint256 claimableAmount = _getClaimableAmount(scheduleId);
        uint256 unvestedAmount = schedule.totalAmount - schedule.claimedAmount - claimableAmount;

        if (claimableAmount > 0) {
            schedule.claimedAmount += claimableAmount;
            totalClaimedAmount += claimableAmount;
            token.safeTransfer(schedule.beneficiary, claimableAmount);
        }

        schedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unvestedAmount);
    }


    function withdrawExcessTokens(uint256 amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedTokens = totalVestedAmount - totalClaimedAmount;
        uint256 excessTokens = contractBalance - lockedTokens;

        require(amount <= excessTokens, "Cannot withdraw locked tokens");

        token.safeTransfer(owner(), amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }




    function getVestingSchedule(bytes32 scheduleId)
        external
        view
        onlyValidSchedule(scheduleId)
        returns (VestingSchedule memory)
    {
        return _vestingSchedules[scheduleId];
    }


    function getClaimableAmount(bytes32 scheduleId)
        external
        view
        onlyValidSchedule(scheduleId)
        returns (uint256)
    {
        return _getClaimableAmount(scheduleId);
    }


    function getBeneficiarySchedules(address beneficiary)
        external
        view
        returns (bytes32[] memory)
    {
        return _beneficiarySchedules[beneficiary];
    }


    function getTotalSchedulesCount() external view returns (uint256) {
        return _allScheduleIds.length;
    }


    function getScheduleIdByIndex(uint256 index) external view returns (bytes32) {
        require(index < _allScheduleIds.length, "Index out of bounds");
        return _allScheduleIds[index];
    }




    function _getClaimableAmount(bytes32 scheduleId) internal view returns (uint256) {
        VestingSchedule memory schedule = _vestingSchedules[scheduleId];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount - schedule.claimedAmount;
    }


    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime) {
            return 0;
        }


        uint256 initialRelease = (schedule.totalAmount * schedule.initialReleasePercentage) / PERCENTAGE_DENOMINATOR;


        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return initialRelease;
        }


        uint256 timeElapsed = block.timestamp - schedule.startTime;

        if (timeElapsed >= schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 vestingAmount = schedule.totalAmount - initialRelease;
        uint256 timeBasedVested = (vestingAmount * timeElapsed) / schedule.vestingDuration;

        return initialRelease + timeBasedVested;
    }


    function _generateScheduleId(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                beneficiary,
                totalAmount,
                startTime,
                block.timestamp,
                _allScheduleIds.length
            )
        );
    }
}
