
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
        uint256 duration;
        bool revoked;
    }

    IERC20 public token;
    address public owner;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;


    event VestingCreated(address beneficiary, uint256 amount, uint256 startTime, uint256 duration);
    event TokensReleased(address beneficiary, uint256 amount);
    event VestingRevoked(address beneficiary);


    error Err1();
    error Err2();
    error Err3();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        require(beneficiary != address(0));
        require(amount > 0);
        require(duration > 0);
        require(!beneficiaries[beneficiary]);

        if (startTime < block.timestamp) {
            revert Err1();
        }

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            revoked: false
        });

        beneficiaries[beneficiary] = true;

        require(token.transferFrom(msg.sender, address(this), amount));

        emit VestingCreated(beneficiary, amount, startTime, duration);
    }

    function releaseTokens() external {
        require(beneficiaries[msg.sender]);

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(!schedule.revoked);

        uint256 releasableAmount = calculateReleasableAmount(msg.sender);
        require(releasableAmount > 0);


        schedule.releasedAmount += releasableAmount;

        require(token.transfer(msg.sender, releasableAmount));

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function calculateReleasableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        uint256 vestedAmount;

        if (timeElapsed >= schedule.duration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        require(beneficiaries[beneficiary]);

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked);

        uint256 releasableAmount = calculateReleasableAmount(beneficiary);

        if (releasableAmount > 0) {

            require(token.transfer(beneficiary, releasableAmount));
            schedule.releasedAmount += releasableAmount;
        }


        schedule.revoked = true;

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            require(token.transfer(owner, remainingAmount));
        }

        emit VestingRevoked(beneficiary);
    }

    function getVestingInfo(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        bool revoked,
        uint256 releasableAmount
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.revoked,
            calculateReleasableAmount(beneficiary)
        );
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) {
            revert Err2();
        }


        require(token.transfer(owner, balance));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert Err3();
        }


        owner = newOwner;
    }
}
