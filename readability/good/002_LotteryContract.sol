
pragma solidity ^0.8.0;


contract LotteryContract {

    address public owner;


    enum LotteryState {
        OPEN,
        CALCULATING_WINNER,
        CLOSED
    }


    LotteryState public lotteryState;


    address[] public participants;


    mapping(address => bool) public hasParticipated;


    uint256 public entryFee;


    uint256 public prizePool;


    address public lastWinner;


    uint256 public lastPrizeAmount;


    uint256 public lotteryRound;


    uint256 public minimumParticipants;


    uint256 private randomSeed;


    event ParticipantEntered(address indexed participant, uint256 round);
    event WinnerSelected(address indexed winner, uint256 amount, uint256 round);
    event LotteryStateChanged(LotteryState newState);
    event EntryFeeUpdated(uint256 newFee);
    event MinimumParticipantsUpdated(uint256 newMinimum);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    modifier onlyWhenOpen() {
        require(lotteryState == LotteryState.OPEN, "Lottery is not open");
        _;
    }


    modifier onlyWhenClosed() {
        require(lotteryState == LotteryState.CLOSED, "Lottery is not closed");
        _;
    }


    constructor(uint256 _entryFee, uint256 _minimumParticipants) {
        owner = msg.sender;
        entryFee = _entryFee;
        minimumParticipants = _minimumParticipants;
        lotteryState = LotteryState.OPEN;
        lotteryRound = 1;
        randomSeed = block.timestamp;
    }


    function enterLottery() external payable onlyWhenOpen {
        require(msg.value == entryFee, "Incorrect entry fee");
        require(!hasParticipated[msg.sender], "Already participated in this round");


        participants.push(msg.sender);
        hasParticipated[msg.sender] = true;
        prizePool += msg.value;


        randomSeed = uint256(keccak256(abi.encodePacked(
            randomSeed,
            block.timestamp,
            block.difficulty,
            msg.sender
        )));

        emit ParticipantEntered(msg.sender, lotteryRound);
    }


    function selectWinner() external onlyOwner onlyWhenOpen {
        require(participants.length >= minimumParticipants, "Not enough participants");


        lotteryState = LotteryState.CALCULATING_WINNER;
        emit LotteryStateChanged(lotteryState);


        uint256 winnerIndex = _generateRandomNumber() % participants.length;
        address winner = participants[winnerIndex];


        uint256 maintenanceFee = prizePool * 5 / 100;
        uint256 winnerPrize = prizePool - maintenanceFee;


        lastWinner = winner;
        lastPrizeAmount = winnerPrize;


        payable(winner).transfer(winnerPrize);


        payable(owner).transfer(maintenanceFee);

        emit WinnerSelected(winner, winnerPrize, lotteryRound);


        _resetLottery();
    }


    function _generateRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            randomSeed,
            block.timestamp,
            block.difficulty,
            participants.length
        )));
    }


    function _resetLottery() private {

        for (uint256 i = 0; i < participants.length; i++) {
            hasParticipated[participants[i]] = false;
        }
        delete participants;


        prizePool = 0;
        lotteryRound++;
        lotteryState = LotteryState.OPEN;

        emit LotteryStateChanged(lotteryState);
    }


    function updateEntryFee(uint256 _newEntryFee) external onlyOwner onlyWhenClosed {
        require(_newEntryFee > 0, "Entry fee must be greater than 0");
        entryFee = _newEntryFee;
        emit EntryFeeUpdated(_newEntryFee);
    }


    function updateMinimumParticipants(uint256 _newMinimumParticipants) external onlyOwner onlyWhenClosed {
        require(_newMinimumParticipants > 0, "Minimum participants must be greater than 0");
        minimumParticipants = _newMinimumParticipants;
        emit MinimumParticipantsUpdated(_newMinimumParticipants);
    }


    function openLottery() external onlyOwner onlyWhenClosed {
        lotteryState = LotteryState.OPEN;
        emit LotteryStateChanged(lotteryState);
    }


    function closeLottery() external onlyOwner onlyWhenOpen {
        lotteryState = LotteryState.CLOSED;
        emit LotteryStateChanged(lotteryState);
    }


    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }


    function getAllParticipants() external view returns (address[] memory) {
        return participants;
    }


    function checkParticipation(address _participant) external view returns (bool) {
        return hasParticipated[_participant];
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function emergencyWithdraw() external onlyOwner {
        require(lotteryState == LotteryState.CLOSED, "Can only withdraw when lottery is closed");
        payable(owner).transfer(address(this).balance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different from current owner");
        owner = _newOwner;
    }
}
