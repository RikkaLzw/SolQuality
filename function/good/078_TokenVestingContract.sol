
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenVestingContract is Ownable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unreleasedAmount);

    modifier onlyBeneficiary() {
        require(beneficiaries[msg.sender], "Not a beneficiary");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(!beneficiaries[beneficiary], "Beneficiary already exists");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner validBeneficiary(beneficiary) {
        require(amount > 0, "Amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(cliffDuration <= vestingDuration, "Cliff cannot exceed vesting duration");

        uint256 startTime = block.timestamp;

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: true,
            revoked: false
        });

        beneficiaries[beneficiary] = true;
        totalVestedAmount += amount;

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    function releaseTokens() external onlyBeneficiary nonReentrant {
        address beneficiary = msg.sender;
        uint256 releasableAmount = _getReleasableAmount(beneficiary);

        require(releasableAmount > 0, "No tokens available for release");

        vestingSchedules[beneficiary].releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        require(beneficiaries[beneficiary], "Beneficiary does not exist");
        require(schedule.revocable, "Vesting is not revocable");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 releasableAmount = _getReleasableAmount(beneficiary);
        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
        }

        schedule.revoked = true;
        totalVestedAmount -= unreleasedAmount;

        if (unreleasedAmount > 0) {
            require(token.transfer(owner(), unreleasedAmount), "Token transfer failed");
        }

        emit VestingRevoked(beneficiary, unreleasedAmount);
    }

    function getVestingInfo(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 releasableAmount,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            _getReleasableAmount(beneficiary),
            schedule.revoked
        );
    }

    function _getReleasableAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || !beneficiaries[beneficiary]) {
            return 0;
        }

        return _calculateVestedAmount(schedule) - schedule.releasedAmount;
    }

    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
