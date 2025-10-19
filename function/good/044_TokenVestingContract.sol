
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVestingContract is ReentrancyGuard, Ownable {
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
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public vestingSchedulesCount;
    bytes32[] public vestingScheduleIds;
    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event TokensReleased(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed scheduleId,
        address indexed beneficiary
    );

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(_vestingDuration > 0, "Vesting duration must be greater than zero");
        require(_cliffDuration <= _vestingDuration, "Cliff duration cannot exceed vesting duration");

        bytes32 scheduleId = _generateScheduleId(_beneficiary);

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: true,
            revoked: false
        });

        vestingScheduleIds.push(scheduleId);
        vestingSchedulesCount[_beneficiary]++;
        totalVestedAmount += _totalAmount;

        require(
            token.balanceOf(address(this)) >= totalVestedAmount,
            "Insufficient token balance in contract"
        );

        emit VestingScheduleCreated(scheduleId, _beneficiary, _totalAmount);
    }

    function releaseTokens(bytes32 _scheduleId) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.beneficiary != address(0), "Vesting schedule does not exist");
        require(!schedule.revoked, "Vesting schedule has been revoked");
        require(
            msg.sender == schedule.beneficiary || msg.sender == owner(),
            "Only beneficiary or owner can release tokens"
        );

        uint256 releasableAmount = _getReleasableAmount(_scheduleId);
        require(releasableAmount > 0, "No tokens available for release");

        schedule.releasedAmount += releasableAmount;
        totalVestedAmount -= releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(_scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revokeVestingSchedule(bytes32 _scheduleId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.beneficiary != address(0), "Vesting schedule does not exist");
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");

        uint256 releasableAmount = _getReleasableAmount(_scheduleId);

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(_scheduleId, schedule.beneficiary, releasableAmount);
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        totalVestedAmount -= remainingAmount;
        schedule.revoked = true;

        emit VestingScheduleRevoked(_scheduleId, schedule.beneficiary);
    }

    function getReleasableAmount(bytes32 _scheduleId) external view returns (uint256) {
        return _getReleasableAmount(_scheduleId);
    }

    function getVestingSchedule(bytes32 _scheduleId) external view returns (VestingSchedule memory) {
        return vestingSchedules[_scheduleId];
    }

    function getVestingSchedulesCount() external view returns (uint256) {
        return vestingScheduleIds.length;
    }

    function withdrawExcessTokens(uint256 _amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(_amount <= availableBalance, "Cannot withdraw vested tokens");
        require(token.transfer(owner(), _amount), "Token transfer failed");
    }

    function _getReleasableAmount(bytes32 _scheduleId) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_scheduleId];

        if (schedule.revoked || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 vestedAmount;

        if (elapsedTime >= schedule.vestingDuration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount = (schedule.totalAmount * elapsedTime) / schedule.vestingDuration;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function _generateScheduleId(address _beneficiary) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _beneficiary,
                vestingSchedulesCount[_beneficiary],
                block.timestamp
            )
        );
    }
}
