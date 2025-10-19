
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


    error InvalidInput();
    error NotAuthorized();
    error Failed();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    constructor(address _token) {

        require(_token != address(0));
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
        require(startTime > 0);
        require(!beneficiaries[beneficiary]);


        require(token.transferFrom(msg.sender, address(this), amount));

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            revoked: false
        });

        beneficiaries[beneficiary] = true;


        emit VestingCreated(beneficiary, amount, startTime, duration);
    }

    function releaseTokens() external {

        require(beneficiaries[msg.sender]);

        VestingSchedule storage schedule = vestingSchedules[msg.sender];


        require(!schedule.revoked);
        require(block.timestamp >= schedule.startTime);

        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;


        require(releasableAmount > 0);

        schedule.releasedAmount += releasableAmount;


        require(token.transfer(msg.sender, releasableAmount));

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {

        require(beneficiaries[beneficiary]);
        require(!vestingSchedules[beneficiary].revoked);

        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        schedule.revoked = true;

        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        uint256 remainingAmount = schedule.totalAmount - vestedAmount;

        if (remainingAmount > 0) {

            require(token.transfer(owner, remainingAmount));
        }

        emit VestingRevoked(beneficiary);
    }

    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return schedule.releasedAmount;
        }

        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }

        uint256 timeElapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeElapsed) / schedule.duration;
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        return vestedAmount - vestingSchedules[beneficiary].releasedAmount;
    }

    function transferOwnership(address newOwner) external onlyOwner {

        require(newOwner != address(0));


        owner = newOwner;
    }

    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyOwner {

        require(tokenAddress != address(0));

        IERC20 emergencyToken = IERC20(tokenAddress);


        require(emergencyToken.transfer(owner, amount));


    }

    function updateVestingDuration(address beneficiary, uint256 newDuration) external onlyOwner {

        require(beneficiaries[beneficiary]);
        require(newDuration > 0);
        require(!vestingSchedules[beneficiary].revoked);


        vestingSchedules[beneficiary].duration = newDuration;
    }
}
