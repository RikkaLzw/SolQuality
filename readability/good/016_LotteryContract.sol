
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract LotteryContract is Ownable, ReentrancyGuard, Pausable {


    enum LotteryState {
        OPEN,
        CALCULATING,
        CLOSED
    }


    struct LotteryRound {
        uint256 roundId;
        uint256 ticketPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPrizePool;
        address winner;
        bool isFinalized;
        LotteryState state;
    }


    uint256 public currentRoundId;
    uint256 public constant MINIMUM_TICKET_PRICE = 0.01 ether;
    uint256 public constant MAXIMUM_PARTICIPANTS = 1000;
    uint256 public constant OWNER_FEE_PERCENTAGE = 5;


    mapping(uint256 => LotteryRound) public lotteryRounds;
    mapping(uint256 => address[]) public roundParticipants;
    mapping(uint256 => mapping(address => uint256)) public participantTicketCount;
    mapping(address => uint256) public playerWinnings;


    event LotteryRoundCreated(
        uint256 indexed roundId,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime
    );

    event TicketPurchased(
        uint256 indexed roundId,
        address indexed participant,
        uint256 ticketCount,
        uint256 totalCost
    );

    event WinnerSelected(
        uint256 indexed roundId,
        address indexed winner,
        uint256 prizeAmount
    );

    event PrizeWithdrawn(
        address indexed winner,
        uint256 amount
    );

    event LotteryStateChanged(
        uint256 indexed roundId,
        LotteryState newState
    );


    modifier validRound(uint256 _roundId) {
        require(_roundId <= currentRoundId, "Invalid round ID");
        require(_roundId > 0, "Round ID must be greater than 0");
        _;
    }

    modifier lotteryOpen(uint256 _roundId) {
        require(
            lotteryRounds[_roundId].state == LotteryState.OPEN,
            "Lottery is not open"
        );
        require(
            block.timestamp >= lotteryRounds[_roundId].startTime,
            "Lottery has not started yet"
        );
        require(
            block.timestamp <= lotteryRounds[_roundId].endTime,
            "Lottery has ended"
        );
        _;
    }


    constructor() {
        currentRoundId = 0;
    }


    function createLotteryRound(
        uint256 _ticketPrice,
        uint256 _duration
    ) external onlyOwner whenNotPaused {
        require(_ticketPrice >= MINIMUM_TICKET_PRICE, "Ticket price too low");
        require(_duration >= 1 hours, "Duration must be at least 1 hour");
        require(_duration <= 30 days, "Duration cannot exceed 30 days");


        if (currentRoundId > 0) {
            require(
                lotteryRounds[currentRoundId].state == LotteryState.CLOSED,
                "Previous round must be closed"
            );
        }

        currentRoundId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _duration;

        lotteryRounds[currentRoundId] = LotteryRound({
            roundId: currentRoundId,
            ticketPrice: _ticketPrice,
            startTime: startTime,
            endTime: endTime,
            totalPrizePool: 0,
            winner: address(0),
            isFinalized: false,
            state: LotteryState.OPEN
        });

        emit LotteryRoundCreated(currentRoundId, _ticketPrice, startTime, endTime);
    }


    function buyTickets(
        uint256 _roundId,
        uint256 _ticketCount
    ) external payable validRound(_roundId) lotteryOpen(_roundId) whenNotPaused nonReentrant {
        require(_ticketCount > 0, "Must buy at least one ticket");
        require(_ticketCount <= 100, "Cannot buy more than 100 tickets at once");

        LotteryRound storage round = lotteryRounds[_roundId];
        uint256 totalCost = round.ticketPrice * _ticketCount;
        require(msg.value == totalCost, "Incorrect payment amount");


        if (participantTicketCount[_roundId][msg.sender] == 0) {
            require(
                roundParticipants[_roundId].length < MAXIMUM_PARTICIPANTS,
                "Maximum participants reached"
            );
            roundParticipants[_roundId].push(msg.sender);
        }


        participantTicketCount[_roundId][msg.sender] += _ticketCount;


        round.totalPrizePool += totalCost;

        emit TicketPurchased(_roundId, msg.sender, _ticketCount, totalCost);
    }


    function endLotteryAndSelectWinner(
        uint256 _roundId
    ) external onlyOwner validRound(_roundId) nonReentrant {
        LotteryRound storage round = lotteryRounds[_roundId];
        require(round.state == LotteryState.OPEN, "Lottery is not open");
        require(
            block.timestamp > round.endTime || roundParticipants[_roundId].length == MAXIMUM_PARTICIPANTS,
            "Lottery cannot be ended yet"
        );
        require(roundParticipants[_roundId].length > 0, "No participants");


        round.state = LotteryState.CALCULATING;
        emit LotteryStateChanged(_roundId, LotteryState.CALCULATING);


        address winner = _selectWinner(_roundId);
        round.winner = winner;


        uint256 ownerFee = (round.totalPrizePool * OWNER_FEE_PERCENTAGE) / 100;
        uint256 winnerPrize = round.totalPrizePool - ownerFee;


        playerWinnings[winner] += winnerPrize;


        if (ownerFee > 0) {
            payable(owner()).transfer(ownerFee);
        }


        round.isFinalized = true;
        round.state = LotteryState.CLOSED;

        emit WinnerSelected(_roundId, winner, winnerPrize);
        emit LotteryStateChanged(_roundId, LotteryState.CLOSED);
    }


    function withdrawWinnings() external nonReentrant {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");

        playerWinnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit PrizeWithdrawn(msg.sender, amount);
    }


    function _selectWinner(uint256 _roundId) private view returns (address) {
        address[] memory participants = roundParticipants[_roundId];
        require(participants.length > 0, "No participants");


        address[] memory weightedParticipants = new address[](0);
        uint256 totalTickets = 0;


        for (uint256 i = 0; i < participants.length; i++) {
            totalTickets += participantTicketCount[_roundId][participants[i]];
        }


        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    participants.length,
                    _roundId
                )
            )
        ) % totalTickets;


        uint256 currentWeight = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            currentWeight += participantTicketCount[_roundId][participants[i]];
            if (randomNumber < currentWeight) {
                return participants[i];
            }
        }


        return participants[participants.length - 1];
    }


    function getParticipantCount(uint256 _roundId) external view validRound(_roundId) returns (uint256) {
        return roundParticipants[_roundId].length;
    }


    function getRoundParticipants(uint256 _roundId) external view validRound(_roundId) returns (address[] memory) {
        return roundParticipants[_roundId];
    }


    function getUserTicketCount(
        uint256 _roundId,
        address _participant
    ) external view validRound(_roundId) returns (uint256) {
        return participantTicketCount[_roundId][_participant];
    }


    function getCurrentRoundInfo() external view returns (
        uint256 roundId,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 totalPrizePool,
        LotteryState state,
        uint256 participantCount
    ) {
        if (currentRoundId == 0) {
            return (0, 0, 0, 0, 0, LotteryState.CLOSED, 0);
        }

        LotteryRound memory round = lotteryRounds[currentRoundId];
        return (
            round.roundId,
            round.ticketPrice,
            round.startTime,
            round.endTime,
            round.totalPrizePool,
            round.state,
            roundParticipants[currentRoundId].length
        );
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw() external onlyOwner {
        require(paused(), "Contract must be paused");
        payable(owner()).transfer(address(this).balance);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
