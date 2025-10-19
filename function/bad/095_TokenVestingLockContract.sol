
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
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    mapping(address => mapping(address => VestingSchedule)) public vestingSchedules;
    mapping(address => address[]) public beneficiaryTokens;
    mapping(address => uint256) public totalLockedTokens;

    address public owner;
    uint256 public totalContracts;
    bool public paused;

    event VestingScheduleCreated(address indexed beneficiary, address indexed token, uint256 amount);
    event TokensReleased(address indexed beneficiary, address indexed token, uint256 amount);
    event VestingRevoked(address indexed beneficiary, address indexed token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createVestingScheduleAndManageContract(
        address beneficiary,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool shouldUpdatePauseState,
        bool newPauseState
    ) public onlyOwner {

        require(beneficiary != address(0), "Invalid beneficiary");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");
        require(vestingSchedules[beneficiary][token].totalAmount == 0, "Schedule already exists");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        vestingSchedules[beneficiary][token] = VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        beneficiaryTokens[beneficiary].push(token);
        totalLockedTokens[token] += amount;
        totalContracts++;

        emit VestingScheduleCreated(beneficiary, token, amount);


        if (shouldUpdatePauseState) {
            paused = newPauseState;
        }


        _cleanupExpiredSchedules(beneficiary);
    }


    function calculateVestedAmount(address beneficiary, address token) public view returns (uint256) {
        return _calculateVestedAmountInternal(beneficiary, token);
    }


    function releaseTokensWithComplexLogic(address beneficiary, address token) public notPaused {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][token];

        if (schedule.totalAmount > 0) {
            if (!schedule.revoked) {
                if (block.timestamp >= schedule.startTime) {
                    if (block.timestamp >= schedule.startTime + schedule.cliffDuration) {
                        uint256 vestedAmount = _calculateVestedAmountInternal(beneficiary, token);

                        if (vestedAmount > schedule.releasedAmount) {
                            uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

                            if (releasableAmount > 0) {
                                if (IERC20(token).balanceOf(address(this)) >= releasableAmount) {
                                    schedule.releasedAmount += releasableAmount;
                                    totalLockedTokens[token] -= releasableAmount;

                                    if (schedule.releasedAmount >= schedule.totalAmount) {
                                        if (schedule.totalAmount == schedule.releasedAmount) {
                                            _removeFromBeneficiaryTokens(beneficiary, token);
                                        }
                                    }

                                    IERC20(token).transfer(beneficiary, releasableAmount);
                                    emit TokensReleased(beneficiary, token, releasableAmount);
                                } else {
                                    revert("Insufficient contract balance");
                                }
                            } else {
                                revert("No tokens to release");
                            }
                        } else {
                            revert("No vested tokens available");
                        }
                    } else {
                        revert("Cliff period not reached");
                    }
                } else {
                    revert("Vesting not started");
                }
            } else {
                revert("Vesting schedule revoked");
            }
        } else {
            revert("No vesting schedule found");
        }
    }

    function revokeVesting(address beneficiary, address token) public onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary][token];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");

        uint256 vestedAmount = _calculateVestedAmountInternal(beneficiary, token);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;

        if (releasableAmount > 0) {
            schedule.releasedAmount += releasableAmount;
            IERC20(token).transfer(beneficiary, releasableAmount);
        }

        uint256 revokedAmount = schedule.totalAmount - schedule.releasedAmount;
        if (revokedAmount > 0) {
            totalLockedTokens[token] -= revokedAmount;
            IERC20(token).transfer(owner, revokedAmount);
        }

        schedule.revoked = true;
        emit VestingRevoked(beneficiary, token);
    }

    function getVestingSchedule(address beneficiary, address token) public view returns (VestingSchedule memory) {
        return vestingSchedules[beneficiary][token];
    }

    function getBeneficiaryTokens(address beneficiary) public view returns (address[] memory) {
        return beneficiaryTokens[beneficiary];
    }

    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    function _calculateVestedAmountInternal(address beneficiary, address token) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary][token];

        if (schedule.totalAmount == 0 || schedule.revoked) {
            return 0;
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

    function _cleanupExpiredSchedules(address beneficiary) internal {
        address[] storage tokens = beneficiaryTokens[beneficiary];
        for (uint i = 0; i < tokens.length; i++) {
            VestingSchedule storage schedule = vestingSchedules[beneficiary][tokens[i]];
            if (schedule.releasedAmount >= schedule.totalAmount || schedule.revoked) {

            }
        }
    }

    function _removeFromBeneficiaryTokens(address beneficiary, address token) internal {
        address[] storage tokens = beneficiaryTokens[beneficiary];
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }
}
