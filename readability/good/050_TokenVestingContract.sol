
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
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => bytes32[]) public beneficiarySchedules;
    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;


    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 unreleased
    );


    modifier onlyValidSchedule(bytes32 scheduleId) {
        require(vestingSchedules[scheduleId].beneficiary != address(0), "Vesting schedule does not exist");
        _;
    }

    modifier onlyBeneficiary(bytes32 scheduleId) {
        require(msg.sender == vestingSchedules[scheduleId].beneficiary, "Only beneficiary can call this function");
        _;
    }


    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(tokenAddress);
    }


    function createVestingSchedule(
        address beneficiaryAddress,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDurationInSeconds,
        uint256 vestingDurationInSeconds,
        bool isRevocable
    ) external onlyOwner returns (bytes32) {
        require(beneficiaryAddress != address(0), "Beneficiary address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(vestingDurationInSeconds > 0, "Vesting duration must be greater than zero");
        require(cliffDurationInSeconds <= vestingDurationInSeconds, "Cliff duration cannot exceed vesting duration");
        require(startTime >= block.timestamp, "Start time cannot be in the past");


        require(token.balanceOf(address(this)) >= totalVestedAmount + amount, "Insufficient token balance");


        bytes32 scheduleId = keccak256(
            abi.encodePacked(
                beneficiaryAddress,
                amount,
                startTime,
                cliffDurationInSeconds,
                vestingDurationInSeconds,
                block.timestamp
            )
        );


        require(vestingSchedules[scheduleId].beneficiary == address(0), "Schedule ID already exists");


        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiaryAddress,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDurationInSeconds,
            vestingDuration: vestingDurationInSeconds,
            revocable: isRevocable,
            revoked: false
        });


        beneficiarySchedules[beneficiaryAddress].push(scheduleId);


        totalVestedAmount += amount;

        emit VestingScheduleCreated(
            scheduleId,
            beneficiaryAddress,
            amount,
            startTime,
            cliffDurationInSeconds,
            vestingDurationInSeconds
        );

        return scheduleId;
    }


    function releaseTokens(bytes32 scheduleId)
        external
        nonReentrant
        onlyValidSchedule(scheduleId)
        onlyBeneficiary(scheduleId)
    {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 releasableAmount = calculateReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens available for release");


        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;


        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
    }


    function revokeVestingSchedule(bytes32 scheduleId)
        external
        onlyOwner
        onlyValidSchedule(scheduleId)
    {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Vesting schedule is not revocable");
        require(!schedule.revoked, "Vesting schedule already revoked");

        uint256 releasableAmount = calculateReleasableAmount(scheduleId);
        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;


        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer to beneficiary failed");
        }


        schedule.revoked = true;


        if (unreleasedAmount > 0) {
            totalVestedAmount -= unreleasedAmount;
            require(token.transfer(owner(), unreleasedAmount), "Token transfer to owner failed");
        }

        emit VestingScheduleRevoked(scheduleId, schedule.beneficiary, unreleasedAmount);
    }


    function calculateReleasableAmount(bytes32 scheduleId)
        public
        view
        onlyValidSchedule(scheduleId)
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint256 vestedAmount = calculateVestedAmount(scheduleId);
        return vestedAmount - schedule.releasedAmount;
    }


    function calculateVestedAmount(bytes32 scheduleId)
        public
        view
        onlyValidSchedule(scheduleId)
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

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
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }


    function getBeneficiarySchedules(address beneficiaryAddress)
        external
        view
        returns (bytes32[] memory)
    {
        return beneficiarySchedules[beneficiaryAddress];
    }


    function getVestingSchedule(bytes32 scheduleId)
        external
        view
        onlyValidSchedule(scheduleId)
        returns (VestingSchedule memory)
    {
        return vestingSchedules[scheduleId];
    }


    function getAvailableTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this)) - (totalVestedAmount - totalReleasedAmount);
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - (totalVestedAmount - totalReleasedAmount);
        require(amount <= availableBalance, "Insufficient available balance");
        require(token.transfer(owner(), amount), "Token transfer failed");
    }
}
