
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
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    address public owner;

    mapping(address => VestingSchedule) private vestingSchedules;
    mapping(address => bool) public beneficiaries;

    uint256 public totalVestedTokens;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyBeneficiary() {
        require(beneficiaries[msg.sender], "Not a beneficiary");
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be positive");
        require(_vestingDuration > 0, "Invalid vesting duration");
        require(!beneficiaries[_beneficiary], "Schedule already exists");

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: true,
            revoked: false
        });

        beneficiaries[_beneficiary] = true;
        totalVestedTokens += _amount;

        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        emit VestingScheduleCreated(
            _beneficiary,
            _amount,
            block.timestamp,
            _cliffDuration,
            _vestingDuration
        );
    }

    function releaseTokens() external onlyBeneficiary {
        uint256 releasableAmount = _getReleasableAmount(msg.sender);
        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[msg.sender].releasedAmount += releasableAmount;

        require(
            token.transfer(msg.sender, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(beneficiaries[_beneficiary], "No vesting schedule");
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _getVestedAmount(_beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        schedule.revoked = true;
        schedule.totalAmount = vestedAmount;
        totalVestedTokens -= unvestedAmount;

        if (unvestedAmount > 0) {
            require(
                token.transfer(owner, unvestedAmount),
                "Token transfer failed"
            );
        }

        emit VestingRevoked(_beneficiary, unvestedAmount);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function getVestingSchedule(address _beneficiary)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[_beneficiary];
    }

    function getReleasableAmount(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return _getReleasableAmount(_beneficiary);
    }

    function getVestedAmount(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return _getVestedAmount(_beneficiary);
    }

    function _getReleasableAmount(address _beneficiary)
        private
        view
        returns (uint256)
    {
        return _getVestedAmount(_beneficiary) - vestingSchedules[_beneficiary].releasedAmount;
    }

    function _getVestedAmount(address _beneficiary)
        private
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.revoked) {
            return schedule.totalAmount;
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
}
