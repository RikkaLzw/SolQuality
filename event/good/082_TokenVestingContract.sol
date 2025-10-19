
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
    mapping(address => uint256) public vestingScheduleCount;
    bytes32[] public vestingScheduleIds;
    uint256 public totalVestedAmount;

    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    );

    event TokensReleased(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 amount
    );

    event VestingScheduleRevoked(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        uint256 unvestedAmount
    );

    event TokensWithdrawn(
        address indexed owner,
        uint256 amount
    );

    constructor(address _token) {
        require(_token != address(0), "TokenVestingContract: token address cannot be zero");
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
        require(_beneficiary != address(0), "TokenVestingContract: beneficiary cannot be zero address");
        require(_totalAmount > 0, "TokenVestingContract: total amount must be greater than zero");
        require(_vestingDuration > 0, "TokenVestingContract: vesting duration must be greater than zero");
        require(_cliffDuration <= _vestingDuration, "TokenVestingContract: cliff duration cannot exceed vesting duration");

        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(availableBalance >= _totalAmount, "TokenVestingContract: insufficient contract balance for vesting");

        bytes32 vestingScheduleId = generateVestingScheduleId(_beneficiary, vestingScheduleCount[_beneficiary]);

        vestingSchedules[vestingScheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });

        vestingScheduleIds.push(vestingScheduleId);
        vestingScheduleCount[_beneficiary]++;
        totalVestedAmount += _totalAmount;

        emit VestingScheduleCreated(
            vestingScheduleId,
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable
        );
    }

    function release(bytes32 _vestingScheduleId) external nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[_vestingScheduleId];

        require(vestingSchedule.beneficiary != address(0), "TokenVestingContract: vesting schedule does not exist");
        require(!vestingSchedule.revoked, "TokenVestingContract: vesting schedule has been revoked");
        require(msg.sender == vestingSchedule.beneficiary, "TokenVestingContract: only beneficiary can release tokens");

        uint256 releasableAmount = getReleasableAmount(_vestingScheduleId);
        require(releasableAmount > 0, "TokenVestingContract: no tokens available for release");

        vestingSchedule.releasedAmount += releasableAmount;

        require(token.transfer(vestingSchedule.beneficiary, releasableAmount), "TokenVestingContract: token transfer failed");

        emit TokensReleased(_vestingScheduleId, vestingSchedule.beneficiary, releasableAmount);
    }

    function revoke(bytes32 _vestingScheduleId) external onlyOwner {
        VestingSchedule storage vestingSchedule = vestingSchedules[_vestingScheduleId];

        require(vestingSchedule.beneficiary != address(0), "TokenVestingContract: vesting schedule does not exist");
        require(vestingSchedule.revocable, "TokenVestingContract: vesting schedule is not revocable");
        require(!vestingSchedule.revoked, "TokenVestingContract: vesting schedule already revoked");

        uint256 vestedAmount = getVestedAmount(_vestingScheduleId);
        uint256 unvestedAmount = vestingSchedule.totalAmount - vestedAmount;

        vestingSchedule.revoked = true;
        totalVestedAmount -= unvestedAmount;

        if (vestedAmount > vestingSchedule.releasedAmount) {
            uint256 releasableAmount = vestedAmount - vestingSchedule.releasedAmount;
            vestingSchedule.releasedAmount = vestedAmount;
            require(token.transfer(vestingSchedule.beneficiary, releasableAmount), "TokenVestingContract: token transfer failed");
            emit TokensReleased(_vestingScheduleId, vestingSchedule.beneficiary, releasableAmount);
        }

        emit VestingScheduleRevoked(_vestingScheduleId, vestingSchedule.beneficiary, unvestedAmount);
    }

    function withdraw(uint256 _amount) external onlyOwner {
        uint256 availableBalance = token.balanceOf(address(this)) - totalVestedAmount;
        require(_amount <= availableBalance, "TokenVestingContract: insufficient available balance");
        require(_amount > 0, "TokenVestingContract: withdrawal amount must be greater than zero");

        require(token.transfer(owner(), _amount), "TokenVestingContract: token transfer failed");

        emit TokensWithdrawn(owner(), _amount);
    }

    function getVestingSchedule(bytes32 _vestingScheduleId)
        external
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[_vestingScheduleId];
    }

    function getReleasableAmount(bytes32 _vestingScheduleId) public view returns (uint256) {
        VestingSchedule memory vestingSchedule = vestingSchedules[_vestingScheduleId];

        if (vestingSchedule.revoked) {
            return 0;
        }

        uint256 vestedAmount = getVestedAmount(_vestingScheduleId);
        return vestedAmount - vestingSchedule.releasedAmount;
    }

    function getVestedAmount(bytes32 _vestingScheduleId) public view returns (uint256) {
        VestingSchedule memory vestingSchedule = vestingSchedules[_vestingScheduleId];

        if (block.timestamp < vestingSchedule.startTime + vestingSchedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= vestingSchedule.startTime + vestingSchedule.vestingDuration) {
            return vestingSchedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - vestingSchedule.startTime;
        return (vestingSchedule.totalAmount * timeFromStart) / vestingSchedule.vestingDuration;
    }

    function generateVestingScheduleId(address _beneficiary, uint256 _index)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_beneficiary, _index));
    }

    function getVestingScheduleCount() external view returns (uint256) {
        return vestingScheduleIds.length;
    }

    function getAvailableBalance() external view returns (uint256) {
        return token.balanceOf(address(this)) - totalVestedAmount;
    }
}
