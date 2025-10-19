
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLock {
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

    modifier validBeneficiary(address _beneficiary) {

        require(_beneficiary != address(0));
        require(beneficiaries[_beneficiary]);
        _;
    }

    constructor(address _token) {

        require(_token != address(0));
        token = IERC20(_token);
        owner = msg.sender;
    }

    function createVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration
    ) external onlyOwner {

        require(_beneficiary != address(0));
        require(_amount > 0);
        require(_duration > 0);
        require(_startTime >= block.timestamp);
        require(!beneficiaries[_beneficiary]);


        require(token.transferFrom(msg.sender, address(this), _amount));

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: _startTime,
            duration: _duration,
            revoked: false
        });

        beneficiaries[_beneficiary] = true;



        emit VestingCreated(_beneficiary, _amount, _startTime, _duration);
    }

    function releaseTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];


        require(beneficiaries[msg.sender]);
        require(!schedule.revoked);
        require(block.timestamp >= schedule.startTime);

        uint256 releasableAmount = calculateReleasableAmount(msg.sender);


        require(releasableAmount > 0);


        schedule.releasedAmount += releasableAmount;


        require(token.transfer(msg.sender, releasableAmount));

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address _beneficiary) external onlyOwner validBeneficiary(_beneficiary) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];


        require(!schedule.revoked);

        uint256 releasableAmount = calculateReleasableAmount(_beneficiary);

        if (releasableAmount > 0) {

            schedule.releasedAmount += releasableAmount;


            require(token.transfer(_beneficiary, releasableAmount));
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;


        schedule.revoked = true;

        if (remainingAmount > 0) {

            require(token.transfer(owner, remainingAmount));
        }

        emit VestingRevoked(_beneficiary);
    }

    function calculateReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

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

    function getVestingSchedule(address _beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.duration,
            schedule.revoked
        );
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));


        require(balance > 0);


        require(token.transfer(owner, balance));


    }

    function transferOwnership(address _newOwner) external onlyOwner {

        require(_newOwner != address(0));


        owner = _newOwner;
    }
}
