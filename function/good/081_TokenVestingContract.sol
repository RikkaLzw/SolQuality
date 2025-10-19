
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
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
    address public owner;

    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public vestingCount;
    mapping(address => bytes32[]) public beneficiarySchedules;

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

    event VestingRevoked(bytes32 indexed scheduleId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validSchedule(bytes32 scheduleId) {
        require(vestingSchedules[scheduleId].beneficiary != address(0), "Invalid schedule");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner returns (bytes32) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be positive");
        require(vestingDuration > 0, "Invalid vesting duration");

        bytes32 scheduleId = _generateScheduleId(beneficiary, amount);
        require(vestingSchedules[scheduleId].beneficiary == address(0), "Schedule exists");

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: true,
            revoked: false
        });

        vestingCount[beneficiary]++;
        beneficiarySchedules[beneficiary].push(scheduleId);
        totalVestedAmount += amount;

        emit VestingScheduleCreated(scheduleId, beneficiary, amount);
        return scheduleId;
    }

    function releaseVestedTokens(bytes32 scheduleId)
        external
        validSchedule(scheduleId)
        returns (uint256)
    {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(!schedule.revoked, "Schedule revoked");
        require(
            msg.sender == schedule.beneficiary || msg.sender == owner,
            "Not authorized"
        );

        uint256 releasableAmount = _calculateReleasableAmount(scheduleId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;

        require(
            token.transfer(schedule.beneficiary, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(scheduleId, schedule.beneficiary, releasableAmount);
        return releasableAmount;
    }

    function revokeVesting(bytes32 scheduleId)
        external
        onlyOwner
        validSchedule(scheduleId)
    {
        VestingSchedule storage schedule = vestingSchedules[scheduleId];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = _calculateReleasableAmount(scheduleId);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(
                token.transfer(schedule.beneficiary, releasableAmount),
                "Token transfer failed"
            );
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            totalVestedAmount -= remainingAmount;
            require(
                token.transfer(owner, remainingAmount),
                "Token transfer failed"
            );
        }

        schedule.revoked = true;
        emit VestingRevoked(scheduleId);
    }

    function getVestingSchedule(bytes32 scheduleId)
        external
        view
        validSchedule(scheduleId)
        returns (VestingSchedule memory)
    {
        return vestingSchedules[scheduleId];
    }

    function getReleasableAmount(bytes32 scheduleId)
        external
        view
        validSchedule(scheduleId)
        returns (uint256)
    {
        return _calculateReleasableAmount(scheduleId);
    }

    function getBeneficiarySchedules(address beneficiary)
        external
        view
        returns (bytes32[] memory)
    {
        return beneficiarySchedules[beneficiary];
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _calculateReleasableAmount(bytes32 scheduleId)
        internal
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[scheduleId];

        if (schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;
        uint256 cliffEnd = schedule.startTime + schedule.cliffDuration;

        if (currentTime < cliffEnd) {
            return 0;
        }

        uint256 vestingEnd = schedule.startTime + schedule.vestingDuration;
        uint256 vestedAmount;

        if (currentTime >= vestingEnd) {
            vestedAmount = schedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime - schedule.startTime;
            vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.vestingDuration;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function _generateScheduleId(address beneficiary, uint256 amount)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                beneficiary,
                amount,
                block.timestamp,
                vestingCount[beneficiary]
            )
        );
    }
}
