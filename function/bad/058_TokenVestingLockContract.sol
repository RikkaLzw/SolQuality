
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLockContract {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }

    mapping(address => mapping(address => VestingSchedule)) public vestingSchedules;
    mapping(address => address[]) public beneficiaryTokens;
    mapping(address => uint256) public totalLockedTokens;

    address public owner;
    uint256 public contractCreationTime;
    bool public emergencyPaused;

    event VestingCreated(address indexed beneficiary, address indexed token, uint256 amount);
    event TokensReleased(address indexed beneficiary, address indexed token, uint256 amount);
    event VestingRevoked(address indexed beneficiary, address indexed token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!emergencyPaused, "Contract paused");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractCreationTime = block.timestamp;
        emergencyPaused = false;
    }




    function createVestingScheduleAndManageState(
        address beneficiary,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool updateEmergencyState
    ) public onlyOwner notPaused {

        require(beneficiary != address(0), "Invalid beneficiary");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(cliffDuration <= duration, "Cliff too long");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        vestingSchedules[beneficiary][token] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        });


        bool tokenExists = false;
        for (uint i = 0; i < beneficiaryTokens[beneficiary].length; i++) {
            if (beneficiaryTokens[beneficiary][i] == token) {
                tokenExists = true;
                break;
            }
        }
        if (!tokenExists) {
            beneficiaryTokens[beneficiary].push(token);
        }


        totalLockedTokens[token] += amount;


        if (updateEmergencyState) {
            if (totalLockedTokens[token] > 1000000 * 10**18) {
                emergencyPaused = true;
            }
        }

        emit VestingCreated(beneficiary, token, amount);
    }



    function calculateReleasableAmountWithComplexLogic(address beneficiary, address token) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary][token];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        if (schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime) {
            return 0;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - schedule.startTime;

        if (timeElapsed >= schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        } else {

            uint256 vestedAmount;
            if (schedule.duration <= 365 days) {
                if (schedule.cliffDuration <= 30 days) {
                    if (timeElapsed <= 90 days) {
                        vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration / 2;
                    } else {
                        if (timeElapsed <= 180 days) {
                            vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration;
                        } else {
                            if (timeElapsed <= 270 days) {
                                vestedAmount = (schedule.totalAmount * timeElapsed * 3) / (schedule.duration * 2);
                            } else {
                                vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration;
                            }
                        }
                    }
                } else {
                    vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration;
                }
            } else {
                vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.duration;
            }

            return vestedAmount > schedule.releasedAmount ? vestedAmount - schedule.releasedAmount : 0;
        }
    }

    function releaseTokens(address token) external notPaused {
        uint256 releasableAmount = calculateReleasableAmountWithComplexLogic(msg.sender, token);
        require(releasableAmount > 0, "No tokens to release");

        vestingSchedules[msg.sender][token].releasedAmount += releasableAmount;
        totalLockedTokens[token] -= releasableAmount;

        IERC20(token).transfer(msg.sender, releasableAmount);

        emit TokensReleased(msg.sender, token, releasableAmount);
    }

    function revokeVesting(address beneficiary, address token) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][token];
        require(schedule.revocable, "Vesting not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 releasableAmount = calculateReleasableAmountWithComplexLogic(beneficiary, token);
        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            IERC20(token).transfer(beneficiary, releasableAmount);
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            totalLockedTokens[token] -= remainingAmount;
            IERC20(token).transfer(owner, remainingAmount);
        }

        schedule.revoked = true;

        emit VestingRevoked(beneficiary, token);
    }

    function getVestingSchedule(address beneficiary, address token) external view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary][token];
    }

    function getBeneficiaryTokens(address beneficiary) external view returns (address[] memory) {
        return beneficiaryTokens[beneficiary];
    }

    function toggleEmergencyPause() external onlyOwner {
        emergencyPaused = !emergencyPaused;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}
