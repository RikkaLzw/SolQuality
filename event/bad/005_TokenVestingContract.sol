
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingContract {
    IERC20 public token;
    address public owner;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        bool revoked;
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public beneficiaries;


    event VestingCreated(address beneficiary, uint256 amount, uint256 startTime, uint256 duration);
    event TokensReleased(address beneficiary, uint256 amount);
    event VestingRevoked(address beneficiary);


    error InvalidInput();
    error NotAuthorized();
    error Failed();

    constructor(address _token) {
        require(_token != address(0));
        token = IERC20(_token);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
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

    function release() external {
        require(beneficiaries[msg.sender]);

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(!schedule.revoked);

        uint256 releasableAmount = calculateReleasableAmount(msg.sender);
        require(releasableAmount > 0);

        schedule.releasedAmount += releasableAmount;



        require(token.transfer(msg.sender, releasableAmount));

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function revokeVesting(address _beneficiary) external onlyOwner {
        require(beneficiaries[_beneficiary]);

        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        require(!schedule.revoked);

        uint256 releasableAmount = calculateReleasableAmount(_beneficiary);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            require(token.transfer(_beneficiary, releasableAmount));
        }

        schedule.revoked = true;



        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            require(token.transfer(owner, remainingAmount));
        }

        emit VestingRevoked(_beneficiary);
    }

    function calculateReleasableAmount(address _beneficiary) public view returns (uint256) {
        if (!beneficiaries[_beneficiary]) {
            return 0;
        }

        VestingSchedule memory schedule = vestingSchedules[_beneficiary];

        if (schedule.revoked || block.timestamp < schedule.startTime) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 vestedAmount;

        if (elapsedTime >= schedule.duration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount = (schedule.totalAmount * elapsedTime) / schedule.duration;
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

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));


        owner = _newOwner;
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(0));
        require(_amount > 0);

        IERC20(_token).transfer(owner, _amount);


    }
}
