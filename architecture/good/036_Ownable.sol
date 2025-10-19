
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract TokenVestingLockContract is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant MIN_LOCK_DURATION = 1 days;
    uint256 private constant MAX_LOCK_DURATION = 1095 days;


    struct VestingInfo {
        address beneficiary;
        IERC20 token;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }


    mapping(bytes32 => VestingInfo) private _vestingSchedules;
    mapping(address => uint256) private _vestingSchedulesCount;
    mapping(address => mapping(uint256 => bytes32)) private _vestingScheduleIds;

    uint256 private _vestingSchedulesTotalAmount;
    bytes32[] private _vestingScheduleIdList;


    event VestingScheduleCreated(
        bytes32 indexed vestingScheduleId,
        address indexed beneficiary,
        address indexed token,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
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
        uint256 unreleasedAmount
    );


    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(_vestingSchedules[vestingScheduleId].beneficiary != address(0), "Vesting schedule does not exist");
        _;
    }

    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(!_vestingSchedules[vestingScheduleId].revoked, "Vesting schedule has been revoked");
        _;
    }

    modifier onlyBeneficiaryOrOwner(bytes32 vestingScheduleId) {
        require(
            msg.sender == _vestingSchedules[vestingScheduleId].beneficiary ||
            msg.sender == owner(),
            "Only beneficiary or owner can perform this action"
        );
        _;
    }


    function createVestingSchedule(
        address beneficiary,
        IERC20 token,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    ) external onlyOwner nonReentrant {
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(address(token) != address(0), "Token cannot be zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(duration >= MIN_LOCK_DURATION && duration <= MAX_LOCK_DURATION, "Invalid duration");
        require(cliffDuration <= duration, "Cliff duration cannot exceed total duration");
        require(startTime >= block.timestamp, "Start time cannot be in the past");


        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        bytes32 vestingScheduleId = _generateVestingScheduleId(beneficiary, token, amount, startTime);

        _vestingSchedules[vestingScheduleId] = VestingInfo({
            beneficiary: beneficiary,
            token: token,
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        });

        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.add(amount);
        _vestingScheduleIds[beneficiary][_vestingSchedulesCount[beneficiary]] = vestingScheduleId;
        _vestingSchedulesCount[beneficiary] = _vestingSchedulesCount[beneficiary].add(1);
        _vestingScheduleIdList.push(vestingScheduleId);

        emit VestingScheduleCreated(
            vestingScheduleId,
            beneficiary,
            address(token),
            amount,
            startTime,
            duration,
            cliffDuration,
            revocable
        );
    }


    function release(bytes32 vestingScheduleId)
        external
        nonReentrant
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        onlyBeneficiaryOrOwner(vestingScheduleId)
    {
        VestingInfo storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule);

        require(releasableAmount > 0, "No tokens available for release");

        vestingSchedule.releasedAmount = vestingSchedule.releasedAmount.add(releasableAmount);
        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.sub(releasableAmount);

        require(
            vestingSchedule.token.transfer(vestingSchedule.beneficiary, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(vestingScheduleId, vestingSchedule.beneficiary, releasableAmount);
    }


    function revoke(bytes32 vestingScheduleId)
        external
        onlyOwner
        nonReentrant
        onlyIfVestingScheduleExists(vestingScheduleId)
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingInfo storage vestingSchedule = _vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable, "Vesting schedule is not revocable");

        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule);
        uint256 unreleasedAmount = vestingSchedule.totalAmount.sub(vestingSchedule.releasedAmount).sub(releasableAmount);

        vestingSchedule.revoked = true;

        if (releasableAmount > 0) {
            vestingSchedule.releasedAmount = vestingSchedule.releasedAmount.add(releasableAmount);
            require(
                vestingSchedule.token.transfer(vestingSchedule.beneficiary, releasableAmount),
                "Token transfer to beneficiary failed"
            );
        }

        if (unreleasedAmount > 0) {
            require(
                vestingSchedule.token.transfer(owner(), unreleasedAmount),
                "Token transfer to owner failed"
            );
        }

        _vestingSchedulesTotalAmount = _vestingSchedulesTotalAmount.sub(releasableAmount.add(unreleasedAmount));

        emit VestingScheduleRevoked(vestingScheduleId, vestingSchedule.beneficiary, unreleasedAmount);
    }


    function _computeReleasableAmount(VestingInfo memory vestingSchedule)
        private
        view
        returns (uint256)
    {
        return _computeVestedAmount(vestingSchedule).sub(vestingSchedule.releasedAmount);
    }


    function _computeVestedAmount(VestingInfo memory vestingSchedule)
        private
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;

        if (currentTime < vestingSchedule.startTime.add(vestingSchedule.cliffDuration)) {
            return 0;
        } else if (currentTime >= vestingSchedule.startTime.add(vestingSchedule.duration)) {
            return vestingSchedule.totalAmount;
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.startTime);
            uint256 vestedAmount = vestingSchedule.totalAmount.mul(timeFromStart).div(vestingSchedule.duration);
            return vestedAmount;
        }
    }


    function _generateVestingScheduleId(
        address beneficiary,
        IERC20 token,
        uint256 amount,
        uint256 startTime
    ) private view returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, address(token), amount, startTime, block.timestamp));
    }


    function getVestingSchedule(bytes32 vestingScheduleId)
        external
        view
        returns (VestingInfo memory)
    {
        return _vestingSchedules[vestingScheduleId];
    }

    function getVestingSchedulesCount(address beneficiary)
        external
        view
        returns (uint256)
    {
        return _vestingSchedulesCount[beneficiary];
    }

    function getVestingScheduleIdAtIndex(address beneficiary, uint256 index)
        external
        view
        returns (bytes32)
    {
        return _vestingScheduleIds[beneficiary][index];
    }

    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        onlyIfVestingScheduleExists(vestingScheduleId)
        returns (uint256)
    {
        VestingInfo memory vestingSchedule = _vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    function computeVestedAmount(bytes32 vestingScheduleId)
        external
        view
        onlyIfVestingScheduleExists(vestingScheduleId)
        returns (uint256)
    {
        VestingInfo memory vestingSchedule = _vestingSchedules[vestingScheduleId];
        return _computeVestedAmount(vestingSchedule);
    }

    function getVestingSchedulesTotalAmount()
        external
        view
        returns (uint256)
    {
        return _vestingSchedulesTotalAmount;
    }

    function getAllVestingScheduleIds()
        external
        view
        returns (bytes32[] memory)
    {
        return _vestingScheduleIdList;
    }


    function emergencyWithdraw(IERC20 token, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token.transfer(owner(), amount), "Emergency withdraw failed");
    }
}
