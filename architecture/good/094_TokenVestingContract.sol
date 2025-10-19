
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVestingContract is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days * 10;
    uint256 public constant PRECISION = 1e18;


    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }


    IERC20 public immutable token;
    mapping(address => VestingSchedule) private _vestingSchedules;
    mapping(address => bool) public authorized;

    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;


    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event AuthorizedAdded(address indexed account);
    event AuthorizedRemoved(address indexed account);


    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary");
        _;
    }

    modifier vestingExists(address beneficiary) {
        require(_vestingSchedules[beneficiary].totalAmount > 0, "No vesting schedule");
        _;
    }

    modifier validDuration(uint256 duration) {
        require(
            duration >= MIN_LOCK_DURATION && duration <= MAX_LOCK_DURATION,
            "Invalid duration"
        );
        _;
    }

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        authorized[msg.sender] = true;
    }


    function addAuthorized(address account) external onlyOwner {
        require(account != address(0), "Invalid account");
        authorized[account] = true;
        emit AuthorizedAdded(account);
    }

    function removeAuthorized(address account) external onlyOwner {
        authorized[account] = false;
        emit AuthorizedRemoved(account);
    }


    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    )
        external
        onlyAuthorized
        validBeneficiary(beneficiary)
        validDuration(duration)
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        require(startTime >= block.timestamp, "Start time cannot be in the past");
        require(cliffDuration <= duration, "Cliff duration exceeds total duration");
        require(_vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists");


        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableBalance = contractBalance.sub(totalVestedAmount.sub(totalReleasedAmount));
        require(availableBalance >= amount, "Insufficient contract balance");

        _vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        });

        totalVestedAmount = totalVestedAmount.add(amount);

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            startTime,
            duration,
            cliffDuration,
            revocable
        );
    }


    function release() external nonReentrant {
        _release(msg.sender);
    }

    function releaseFor(address beneficiary)
        external
        onlyAuthorized
        validBeneficiary(beneficiary)
        nonReentrant
    {
        _release(beneficiary);
    }


    function revoke(address beneficiary)
        external
        onlyAuthorized
        validBeneficiary(beneficiary)
        vestingExists(beneficiary)
        nonReentrant
    {
        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        require(schedule.revocable, "Vesting is not revocable");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 vestedAmount = _calculateVestedAmount(beneficiary);
        uint256 releasableAmount = vestedAmount.sub(schedule.releasedAmount);

        if (releasableAmount > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
            totalReleasedAmount = totalReleasedAmount.add(releasableAmount);
            require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
            emit TokensReleased(beneficiary, releasableAmount);
        }

        uint256 unvestedAmount = schedule.totalAmount.sub(schedule.releasedAmount);
        schedule.revoked = true;
        totalVestedAmount = totalVestedAmount.sub(unvestedAmount);

        emit VestingRevoked(beneficiary, unvestedAmount);
    }


    function _release(address beneficiary) internal vestingExists(beneficiary) {
        VestingSchedule storage schedule = _vestingSchedules[beneficiary];
        require(!schedule.revoked, "Vesting has been revoked");

        uint256 releasableAmount = _calculateReleasableAmount(beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        totalReleasedAmount = totalReleasedAmount.add(releasableAmount);

        require(token.transfer(beneficiary, releasableAmount), "Token transfer failed");
        emit TokensReleased(beneficiary, releasableAmount);
    }


    function _calculateVestedAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = _vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        return schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
    }


    function _calculateReleasableAmount(address beneficiary) internal view returns (uint256) {
        uint256 vestedAmount = _calculateVestedAmount(beneficiary);
        return vestedAmount.sub(_vestingSchedules[beneficiary].releasedAmount);
    }


    function getVestingSchedule(address beneficiary)
        external
        view
        returns (
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 startTime,
            uint256 duration,
            uint256 cliffDuration,
            bool revocable,
            bool revoked
        )
    {
        VestingSchedule memory schedule = _vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.cliffDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _calculateReleasableAmount(beneficiary);
    }

    function getVestedAmount(address beneficiary) external view returns (uint256) {
        return _calculateVestedAmount(beneficiary);
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner nonReentrant {
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 lockedAmount = totalVestedAmount.sub(totalReleasedAmount);
        uint256 availableAmount = contractBalance.sub(lockedAmount);

        require(amount <= availableAmount, "Amount exceeds available balance");
        require(token.transfer(owner(), amount), "Token transfer failed");
    }


    function getContractInfo()
        external
        view
        returns (
            uint256 contractBalance,
            uint256 _totalVestedAmount,
            uint256 _totalReleasedAmount,
            uint256 availableBalance
        )
    {
        contractBalance = token.balanceOf(address(this));
        _totalVestedAmount = totalVestedAmount;
        _totalReleasedAmount = totalReleasedAmount;
        availableBalance = contractBalance.sub(totalVestedAmount.sub(totalReleasedAmount));
    }
}
