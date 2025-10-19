
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
    uint256 public totalBeneficiaries;

    event VestingScheduleCreated(address indexed beneficiary, address indexed token, uint256 amount);
    event TokensReleased(address indexed beneficiary, address indexed token, uint256 amount);
    event VestingRevoked(address indexed beneficiary, address indexed token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createVestingScheduleAndManageState(
        address beneficiary,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool shouldUpdateStats
    ) public onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(cliffDuration <= duration, "Cliff too long");


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
        for (uint256 i = 0; i < beneficiaryTokens[beneficiary].length; i++) {
            if (beneficiaryTokens[beneficiary][i] == token) {
                tokenExists = true;
                break;
            }
        }
        if (!tokenExists) {
            beneficiaryTokens[beneficiary].push(token);
        }


        if (shouldUpdateStats) {
            totalLockedTokens[token] += amount;
            if (beneficiaryTokens[beneficiary].length == 1) {
                totalBeneficiaries++;
            }
        }


        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit VestingScheduleCreated(beneficiary, token, amount);
    }


    function calculateVestedAmount(address beneficiary, address token) public view returns (uint256) {
        return _calculateVestedAmount(beneficiary, token);
    }


    function releaseTokensWithComplexLogic(address beneficiary, address token) public {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][token];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Schedule revoked");

        uint256 vestedAmount = _calculateVestedAmount(beneficiary, token);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

        if (releasableAmount > 0) {
            if (block.timestamp >= schedule.startTime) {
                if (block.timestamp >= schedule.startTime + schedule.cliffDuration) {
                    if (schedule.totalAmount >= schedule.releasedAmount + releasableAmount) {
                        if (IERC20(token).balanceOf(address(this)) >= releasableAmount) {
                            if (beneficiary != address(0)) {
                                if (token != address(0)) {
                                    if (releasableAmount <= schedule.totalAmount) {
                                        schedule.releasedAmount += releasableAmount;
                                        totalLockedTokens[token] -= releasableAmount;

                                        bool success = IERC20(token).transfer(beneficiary, releasableAmount);
                                        if (success) {
                                            emit TokensReleased(beneficiary, token, releasableAmount);
                                        } else {
                                            schedule.releasedAmount -= releasableAmount;
                                            totalLockedTokens[token] += releasableAmount;
                                            revert("Transfer failed");
                                        }
                                    } else {
                                        revert("Invalid release amount");
                                    }
                                } else {
                                    revert("Invalid token");
                                }
                            } else {
                                revert("Invalid beneficiary");
                            }
                        } else {
                            revert("Insufficient contract balance");
                        }
                    } else {
                        revert("Exceeds total amount");
                    }
                } else {
                    revert("Cliff period not ended");
                }
            } else {
                revert("Vesting not started");
            }
        }
    }

    function revokeVesting(address beneficiary, address token) public onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][token];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _calculateVestedAmount(beneficiary, token);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            IERC20(token).transfer(beneficiary, releasableAmount);
            emit TokensReleased(beneficiary, token, releasableAmount);
        }

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            totalLockedTokens[token] -= remainingAmount;
            IERC20(token).transfer(owner, remainingAmount);
        }

        schedule.revoked = true;
        emit VestingRevoked(beneficiary, token);
    }

    function _calculateVestedAmount(address beneficiary, address token) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary][token];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.duration;
    }

    function getVestingSchedule(address beneficiary, address token) public view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary][token];
    }

    function getBeneficiaryTokens(address beneficiary) public view returns (address[] memory) {
        return beneficiaryTokens[beneficiary];
    }

    function emergencyWithdraw(address token, uint256 amount) public onlyOwner {
        require(amount <= IERC20(token).balanceOf(address(this)), "Insufficient balance");
        IERC20(token).transfer(owner, amount);
    }
}
