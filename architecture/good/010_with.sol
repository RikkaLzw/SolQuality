
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LotteryContract is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant MAX_TICKETS_PER_ROUND = 1000;
    uint256 public constant MIN_TICKETS_TO_DRAW = 10;
    uint256 public constant OWNER_FEE_PERCENTAGE = 5;
    uint256 public constant ROUND_DURATION = 7 days;


    enum LotteryState {
        OPEN,
        CALCULATING,
        CLOSED
    }


    struct Round {
        uint256 roundId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalTickets;
        uint256 prizePool;
        address winner;
        bool drawn;
        LotteryState state;
    }

    struct Ticket {
        address player;
        uint256 roundId;
        uint256 ticketNumber;
        uint256 timestamp;
    }


    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => Ticket[]) public roundTickets;
    mapping(uint256 => mapping(address => uint256[])) public playerTickets;
    mapping(address => uint256) public playerWinnings;

    uint256 private nonce;


    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event TicketPurchased(address indexed player, uint256 indexed roundId, uint256 ticketNumber);
    event WinnerDrawn(uint256 indexed roundId, address indexed winner, uint256 prize);
    event PrizeWithdrawn(address indexed player, uint256 amount);
    event RoundClosed(uint256 indexed roundId);


    modifier onlyValidRound(uint256 _roundId) {
        require(_roundId <= currentRoundId, "Invalid round ID");
        _;
    }

    modifier onlyOpenRound() {
        require(getCurrentRound().state == LotteryState.OPEN, "Round is not open");
        require(block.timestamp <= getCurrentRound().endTime, "Round has ended");
        _;
    }

    modifier onlyAfterRoundEnd() {
        require(block.timestamp > getCurrentRound().endTime, "Round is still active");
        require(getCurrentRound().state != LotteryState.CALCULATING, "Draw in progress");
        _;
    }

    modifier hasMinimumTickets() {
        require(getCurrentRound().totalTickets >= MIN_TICKETS_TO_DRAW, "Not enough tickets sold");
        _;
    }

    constructor() {
        _startNewRound();
    }


    function buyTickets(uint256 _numberOfTickets)
        external
        payable
        onlyOpenRound
        nonReentrant
    {
        require(_numberOfTickets > 0, "Must buy at least one ticket");
        require(_numberOfTickets <= 10, "Cannot buy more than 10 tickets at once");
        require(msg.value == TICKET_PRICE.mul(_numberOfTickets), "Incorrect payment amount");

        Round storage round = rounds[currentRoundId];
        require(round.totalTickets.add(_numberOfTickets) <= MAX_TICKETS_PER_ROUND, "Exceeds max tickets per round");

        for (uint256 i = 0; i < _numberOfTickets; i++) {
            uint256 ticketNumber = round.totalTickets + i + 1;

            Ticket memory newTicket = Ticket({
                player: msg.sender,
                roundId: currentRoundId,
                ticketNumber: ticketNumber,
                timestamp: block.timestamp
            });

            roundTickets[currentRoundId].push(newTicket);
            playerTickets[currentRoundId][msg.sender].push(ticketNumber);

            emit TicketPurchased(msg.sender, currentRoundId, ticketNumber);
        }

        round.totalTickets = round.totalTickets.add(_numberOfTickets);
        round.prizePool = round.prizePool.add(msg.value);
    }


    function drawWinner()
        external
        onlyOwner
        onlyAfterRoundEnd
        hasMinimumTickets
        nonReentrant
    {
        Round storage round = rounds[currentRoundId];
        require(!round.drawn, "Winner already drawn");
        require(round.state == LotteryState.OPEN, "Round is not in correct state");

        round.state = LotteryState.CALCULATING;

        uint256 winningTicketNumber = _generateRandomNumber(round.totalTickets);
        address winner = roundTickets[currentRoundId][winningTicketNumber - 1].player;

        uint256 ownerFee = round.prizePool.mul(OWNER_FEE_PERCENTAGE).div(100);
        uint256 winnerPrize = round.prizePool.sub(ownerFee);

        round.winner = winner;
        round.drawn = true;
        round.state = LotteryState.CLOSED;

        playerWinnings[winner] = playerWinnings[winner].add(winnerPrize);


        payable(owner()).transfer(ownerFee);

        emit WinnerDrawn(currentRoundId, winner, winnerPrize);
        emit RoundClosed(currentRoundId);

        _startNewRound();
    }


    function withdrawWinnings() external nonReentrant {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");

        playerWinnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit PrizeWithdrawn(msg.sender, amount);
    }


    function emergencyCloseRound() external onlyOwner {
        Round storage round = rounds[currentRoundId];
        require(round.state == LotteryState.OPEN, "Round is not open");

        round.state = LotteryState.CLOSED;


        for (uint256 i = 0; i < roundTickets[currentRoundId].length; i++) {
            address player = roundTickets[currentRoundId][i].player;
            playerWinnings[player] = playerWinnings[player].add(TICKET_PRICE);
        }

        emit RoundClosed(currentRoundId);
        _startNewRound();
    }


    function getCurrentRound() public view returns (Round memory) {
        return rounds[currentRoundId];
    }


    function getPlayerTickets(uint256 _roundId, address _player)
        external
        view
        onlyValidRound(_roundId)
        returns (uint256[] memory)
    {
        return playerTickets[_roundId][_player];
    }


    function getRoundTicketCount(uint256 _roundId)
        external
        view
        onlyValidRound(_roundId)
        returns (uint256)
    {
        return roundTickets[_roundId].length;
    }


    function canDrawCurrentRound() external view returns (bool) {
        Round memory round = getCurrentRound();
        return (
            block.timestamp > round.endTime &&
            round.totalTickets >= MIN_TICKETS_TO_DRAW &&
            !round.drawn &&
            round.state == LotteryState.OPEN
        );
    }


    function _startNewRound() internal {
        currentRoundId++;

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            startTime: block.timestamp,
            endTime: block.timestamp.add(ROUND_DURATION),
            totalTickets: 0,
            prizePool: 0,
            winner: address(0),
            drawn: false,
            state: LotteryState.OPEN
        });

        emit RoundStarted(currentRoundId, block.timestamp, block.timestamp.add(ROUND_DURATION));
    }


    function _generateRandomNumber(uint256 _max) internal returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            nonce,
            blockhash(block.number - 1)
        ))).mod(_max).add(1);
    }
}
