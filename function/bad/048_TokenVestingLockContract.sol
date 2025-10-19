
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
    mapping(address => address[]) public beneficiariesByToken;
    mapping(address => bool) public authorizedTokens;

    address public owner;
    uint256 public totalLocks;
    bool public paused;

    event VestingCreated(address indexed token, address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed token, address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed token, address indexed beneficiary);

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




    function createVestingAndManageToken(
        address token,
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool shouldAuthorizeToken,
        bool shouldPauseContract
    ) public onlyOwner notPaused {

        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(cliffDuration <= duration, "Cliff cannot be longer than duration");

        VestingSchedule storage schedule = vestingSchedules[token][beneficiary];
        require(schedule.totalAmount == 0, "Vesting already exists");

        schedule.totalAmount = amount;
        schedule.startTime = startTime == 0 ? block.timestamp : startTime;
        schedule.duration = duration;
        schedule.cliffDuration = cliffDuration;
        schedule.revocable = revocable;

        beneficiariesByToken[token].push(beneficiary);
        totalLocks++;


        if (shouldAuthorizeToken) {
            authorizedTokens[token] = true;
        }


        if (shouldPauseContract) {
            paused = true;
        }

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit VestingCreated(token, beneficiary, amount);
    }



    function calculateReleasableAmountWithComplexLogic(address token, address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[token][beneficiary];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        if (schedule.revoked) {
            return 0;
        }

        uint256 currentTime = block.timestamp;


        if (currentTime < schedule.startTime) {
            return 0;
        } else {
            if (currentTime < schedule.startTime + schedule.cliffDuration) {
                return 0;
            } else {
                if (currentTime >= schedule.startTime + schedule.duration) {
                    return schedule.totalAmount - schedule.releasedAmount;
                } else {
                    uint256 timeFromStart = currentTime - schedule.startTime;
                    uint256 vestedAmount;

                    if (schedule.duration <= 365 days) {
                        if (timeFromStart <= 30 days) {
                            vestedAmount = (schedule.totalAmount * timeFromStart * 50) / (schedule.duration * 100);
                        } else {
                            if (timeFromStart <= 90 days) {
                                vestedAmount = (schedule.totalAmount * timeFromStart * 75) / (schedule.duration * 100);
                            } else {
                                if (timeFromStart <= 180 days) {
                                    vestedAmount = (schedule.totalAmount * timeFromStart * 90) / (schedule.duration * 100);
                                } else {
                                    vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;
                                }
                            }
                        }
                    } else {
                        if (timeFromStart <= 90 days) {
                            vestedAmount = (schedule.totalAmount * 10) / 100;
                        } else {
                            if (timeFromStart <= 180 days) {
                                vestedAmount = (schedule.totalAmount * 25) / 100;
                            } else {
                                if (timeFromStart <= 365 days) {
                                    vestedAmount = (schedule.totalAmount * 50) / 100;
                                } else {
                                    vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;
                                }
                            }
                        }
                    }

                    return vestedAmount > schedule.releasedAmount ? vestedAmount - schedule.releasedAmount : 0;
                }
            }
        }
    }

    function releaseTokens(address token, address beneficiary) external notPaused {
        uint256 releasableAmount = calculateReleasableAmountWithComplexLogic(token, beneficiary);
        require(releasableAmount > 0, "No tokens to release");

        VestingSchedule storage schedule = vestingSchedules[token][beneficiary];
        schedule.releasedAmount += releasableAmount;

        IERC20(token).transfer(beneficiary, releasableAmount);
        emit TokensReleased(token, beneficiary, releasableAmount);
    }

    function revokeVesting(address token, address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[token][beneficiary];
        require(schedule.revocable, "Vesting is not revocable");
        require(!schedule.revoked, "Vesting already revoked");

        schedule.revoked = true;

        uint256 remainingAmount = schedule.totalAmount - schedule.releasedAmount;
        if (remainingAmount > 0) {
            IERC20(token).transfer(owner, remainingAmount);
        }

        emit VestingRevoked(token, beneficiary);
    }

    function getVestingInfo(address token, address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule memory schedule = vestingSchedules[token][beneficiary];
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

    function setBulkAuthorization(address[] calldata tokens, bool[] calldata statuses) external onlyOwner {
        require(tokens.length == statuses.length, "Arrays length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            authorizedTokens[tokens[i]] = statuses[i];
        }
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    function getBeneficiariesCount(address token) external view returns (uint256) {
        return beneficiariesByToken[token].length;
    }

    function getBeneficiaryAtIndex(address token, uint256 index) external view returns (address) {
        require(index < beneficiariesByToken[token].length, "Index out of bounds");
        return beneficiariesByToken[token][index];
    }
}
