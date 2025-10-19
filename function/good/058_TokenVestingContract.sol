
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
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public vestingCount;
    bytes32[] public vestingIds;

    event VestingScheduleCreated(
        bytes32 indexed vestingId,
        address indexed beneficiary,
        uint256 amount
    );

    event TokensReleased(
        bytes32 indexed vestingId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingRevoked(bytes32 indexed vestingId);

    modifier onlyValidVesting(bytes32 vestingId) {
        require(vestingSchedules[vestingId].beneficiary != address(0), "Vesting not found");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyOwner returns (bytes32) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(cliffDuration <= duration, "Cliff exceeds duration");

        bytes32 vestingId = _generateVestingId(beneficiary, amount);
        require(vestingSchedules[vestingId].beneficiary == address(0), "Vesting already exists");

        vestingSchedules[vestingId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: true,
            revoked: false
        });

        vestingIds.push(vestingId);
        vestingCount[beneficiary]++;

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit VestingScheduleCreated(vestingId, beneficiary, amount);
        return vestingId;
    }

    function releaseTokens(bytes32 vestingId)
        external
        nonReentrant
        onlyValidVesting(vestingId)
    {
        VestingSchedule storage schedule = vestingSchedules[vestingId];
        require(!schedule.revoked, "Vesting revoked");

        uint256 releasableAmount = _calculateReleasableAmount(vestingId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        require(token.transfer(schedule.beneficiary, releasableAmount), "Transfer failed");

        emit TokensReleased(vestingId, schedule.beneficiary, releasableAmount);
    }

    function revokeVesting(bytes32 vestingId)
        external
        onlyOwner
        onlyValidVesting(vestingId)
    {
        VestingSchedule storage schedule = vestingSchedules[vestingId];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _calculateReleasableAmount(vestingId);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(schedule.beneficiary, releasableAmount), "Transfer failed");
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            require(token.transfer(owner(), remainingAmount), "Transfer failed");
        }

        schedule.revoked = true;
        emit VestingRevoked(vestingId);
    }

    function getVestingInfo(bytes32 vestingId)
        external
        view
        onlyValidVesting(vestingId)
        returns (
            address beneficiary,
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 releasableAmount
        )
    {
        VestingSchedule memory schedule = vestingSchedules[vestingId];
        return (
            schedule.beneficiary,
            schedule.totalAmount,
            schedule.releasedAmount,
            _calculateReleasableAmount(vestingId)
        );
    }

    function getVestingsByBeneficiary(address beneficiary)
        external
        view
        returns (bytes32[] memory)
    {
        bytes32[] memory result = new bytes32[](vestingCount[beneficiary]);
        uint256 index = 0;

        for (uint256 i = 0; i < vestingIds.length; i++) {
            if (vestingSchedules[vestingIds[i]].beneficiary == beneficiary) {
                result[index] = vestingIds[i];
                index++;
            }
        }

        return result;
    }

    function _calculateReleasableAmount(bytes32 vestingId)
        internal
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[vestingId];

        if (schedule.revoked || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 vestedAmount = _calculateVestedAmount(vestingId);
        return vestedAmount - schedule.releasedAmount;
    }

    function _calculateVestedAmount(bytes32 vestingId)
        internal
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[vestingId];

        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeElapsed) / schedule.duration;
    }

    function _generateVestingId(address beneficiary, uint256 amount)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(beneficiary, amount, block.timestamp, vestingCount[beneficiary]));
    }
}
