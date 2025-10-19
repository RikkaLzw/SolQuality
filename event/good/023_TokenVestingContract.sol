
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revoked;
    }

    IERC20 public immutable token;
    address public owner;

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 indexed totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(
        address indexed beneficiary,
        uint256 indexed amount,
        uint256 timestamp
    );

    event VestingRevoked(
        address indexed beneficiary,
        uint256 indexed revokedAmount,
        uint256 timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "TokenVesting: caller is not the owner");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "TokenVesting: beneficiary cannot be zero address");
        require(beneficiaries[beneficiary], "TokenVesting: beneficiary does not exist");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "TokenVesting: token address cannot be zero");
        token = IERC20(_token);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(beneficiary != address(0), "TokenVesting: beneficiary cannot be zero address");
        require(totalAmount > 0, "TokenVesting: total amount must be greater than zero");
        require(vestingDuration > 0, "TokenVesting: vesting duration must be greater than zero");
        require(startTime >= block.timestamp, "TokenVesting: start time cannot be in the past");
        require(!beneficiaries[beneficiary], "TokenVesting: beneficiary already has a vesting schedule");

        require(
            token.transferFrom(msg.sender, address(this), totalAmount),
            "TokenVesting: token transfer failed"
        );

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revoked: false
        });

        beneficiaries[beneficiary] = true;
        totalVestedAmount += totalAmount;

        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    function release() external {
        address beneficiary = msg.sender;
        require(beneficiaries[beneficiary], "TokenVesting: no vesting schedule found for caller");

        uint256 releasableAmount = getReleasableAmount(beneficiary);
        require(releasableAmount > 0, "TokenVesting: no tokens available for release");

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "TokenVesting: vesting schedule has been revoked");

        schedule.releasedAmount += releasableAmount;
        totalReleasedAmount += releasableAmount;

        require(
            token.transfer(beneficiary, releasableAmount),
            "TokenVesting: token transfer failed"
        );

        emit TokensReleased(beneficiary, releasableAmount, block.timestamp);
    }

    function revokeVesting(address beneficiary) external onlyOwner validBeneficiary(beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, "TokenVesting: vesting schedule already revoked");

        uint256 releasableAmount = getReleasableAmount(beneficiary);
        uint256 revokedAmount = schedule.totalAmount - schedule.releasedAmount - releasableAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            totalReleasedAmount += releasableAmount;

            require(
                token.transfer(beneficiary, releasableAmount),
                "TokenVesting: token transfer to beneficiary failed"
            );
        }

        if (revokedAmount > 0) {
            totalVestedAmount -= revokedAmount;

            require(
                token.transfer(owner, revokedAmount),
                "TokenVesting: token transfer to owner failed"
            );
        }

        schedule.revoked = true;

        emit VestingRevoked(beneficiary, revokedAmount, block.timestamp);

        if (releasableAmount > 0) {
            emit TokensReleased(beneficiary, releasableAmount, block.timestamp);
        }
    }

    function getReleasableAmount(address beneficiary) public view validBeneficiary(beneficiary) returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked) {
            return 0;
        }

        return getVestedAmount(beneficiary) - schedule.releasedAmount;
    }

    function getVestedAmount(address beneficiary) public view validBeneficiary(beneficiary) returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
    }

    function getVestingSchedule(address beneficiary) external view validBeneficiary(beneficiary) returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revoked
        );
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TokenVesting: new owner cannot be zero address");
        require(newOwner != owner, "TokenVesting: new owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount - totalReleasedAmount;

        require(contractBalance > lockedAmount, "TokenVesting: no excess tokens to withdraw");

        uint256 excessAmount = contractBalance - lockedAmount;

        require(
            token.transfer(owner, excessAmount),
            "TokenVesting: emergency withdrawal failed"
        );
    }
}
