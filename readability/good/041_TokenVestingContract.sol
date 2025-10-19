
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract TokenVestingContract is Ownable, ReentrancyGuard {


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


    mapping(uint256 => VestingSchedule) public vestingSchedules;


    mapping(address => uint256[]) public beneficiaryVestingIds;


    uint256 public vestingScheduleCount;


    uint256 public totalLockedTokens;


    event VestingScheduleCreated(
        uint256 indexed vestingId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(
        uint256 indexed vestingId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(
        uint256 indexed vestingId,
        address indexed beneficiary,
        uint256 revokedAmount
    );

    event EmergencyWithdraw(
        address indexed owner,
        uint256 amount
    );


    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }


    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Total amount must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "Cliff duration cannot exceed vesting duration");
        require(_startTime >= block.timestamp, "Start time cannot be in the past");


        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance >= totalLockedTokens + _totalAmount,
            "Insufficient token balance in contract"
        );


        uint256 vestingId = vestingScheduleCount;
        vestingSchedules[vestingId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });


        beneficiaryVestingIds[_beneficiary].push(vestingId);
        vestingScheduleCount++;
        totalLockedTokens += _totalAmount;

        emit VestingScheduleCreated(
            vestingId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration
        );
    }


    function releaseTokens(uint256 _vestingId) external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[_vestingId];

        require(schedule.beneficiary != address(0), "Vesting schedule does not exist");
        require(!schedule.revoked, "Vesting schedule has been revoked");
        require(
            msg.sender == schedule.beneficiary || msg.sender == owner(),
            "Only beneficiary or owner can release tokens"
        );

        uint256 releasableAmount = calculateReleasableAmount(_vestingId);
        require(releasableAmount > 0, "No tokens available for release");


        schedule.releasedAmount += releasableAmount;
        totalLockedTokens -= releasableAmount;


        require(
            token.transfer(schedule.beneficiary, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(_vestingId, schedule.beneficiary, releasableAmount);
    }


    function revokeVesting(uint256 _vestingId) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_vestingId];

        require(schedule.beneficiary != address(0), "Vesting schedule does not exist");
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");


        uint256 releasableAmount = calculateReleasableAmount(_vestingId);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(schedule.beneficiary, releasableAmount),
                "Token transfer to beneficiary failed"
            );
        }


        uint256 revokedAmount = schedule.totalAmount - schedule.releasedAmount;


        schedule.revoked = true;
        totalLockedTokens -= revokedAmount;


        if (revokedAmount > 0) {
            require(
                token.transfer(owner(), revokedAmount),
                "Token transfer to owner failed"
            );
        }

        emit VestingRevoked(_vestingId, schedule.beneficiary, revokedAmount);

        if (releasableAmount > 0) {
            emit TokensReleased(_vestingId, schedule.beneficiary, releasableAmount);
        }
    }


    function calculateReleasableAmount(uint256 _vestingId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_vestingId];

        if (schedule.beneficiary == address(0) || schedule.revoked) {
            return 0;
        }

        return calculateVestedAmount(_vestingId) - schedule.releasedAmount;
    }


    function calculateVestedAmount(uint256 _vestingId) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_vestingId];

        if (schedule.beneficiary == address(0) || schedule.revoked) {
            return 0;
        }


        if (block.timestamp < schedule.startTime) {
            return 0;
        }


        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }


        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }


        uint256 timeFromStart = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;

        return vestedAmount;
    }


    function getBeneficiaryVestingIds(address _beneficiary) external view returns (uint256[] memory) {
        return beneficiaryVestingIds[_beneficiary];
    }


    function getVestingSchedule(uint256 _vestingId) external view returns (VestingSchedule memory) {
        return vestingSchedules[_vestingId];
    }


    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");

        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableBalance = contractBalance - totalLockedTokens;

        require(_amount <= availableBalance, "Insufficient available balance");

        require(token.transfer(owner(), _amount), "Token transfer failed");

        emit EmergencyWithdraw(owner(), _amount);
    }


    function getAvailableBalance() external view returns (uint256) {
        uint256 contractBalance = token.balanceOf(address(this));
        return contractBalance > totalLockedTokens ? contractBalance - totalLockedTokens : 0;
    }


    function batchCreateVestingSchedules(
        address[] calldata _beneficiaries,
        uint256[] calldata _amounts,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        require(_beneficiaries.length == _amounts.length, "Arrays length mismatch");
        require(_beneficiaries.length > 0, "Empty arrays");

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            createVestingSchedule(
                _beneficiaries[i],
                _amounts[i],
                _startTime,
                _cliffDuration,
                _vestingDuration,
                _revocable
            );
        }
    }
}
