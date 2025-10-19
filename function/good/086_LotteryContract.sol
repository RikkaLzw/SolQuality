
pragma solidity ^0.8.19;

contract LotteryContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    bool public lotteryActive;

    struct Round {
        uint256 roundId;
        address[] participants;
        address winner;
        uint256 prizePool;
        uint256 endTime;
        bool completed;
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => uint256)) public ticketCount;

    event TicketPurchased(address indexed buyer, uint256 indexed round, uint256 tickets);
    event LotteryDrawn(uint256 indexed round, address indexed winner, uint256 prize);
    event LotteryStarted(uint256 indexed round, uint256 ticketPrice, uint256 maxTickets);
    event LotteryEnded(uint256 indexed round);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery not active");
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        currentRound = 1;
        lotteryActive = false;
    }

    function startLottery() external onlyOwner {
        require(!lotteryActive, "Lottery already active");

        lotteryActive = true;
        rounds[currentRound] = Round({
            roundId: currentRound,
            participants: new address[](0),
            winner: address(0),
            prizePool: 0,
            endTime: block.timestamp + 7 days,
            completed: false
        });

        emit LotteryStarted(currentRound, ticketPrice, maxTickets);
    }

    function buyTickets(uint256 _tickets) external payable lotteryIsActive {
        require(_tickets > 0 && _tickets <= 10, "Invalid ticket amount");
        require(msg.value == ticketPrice * _tickets, "Incorrect payment");
        require(block.timestamp < rounds[currentRound].endTime, "Round ended");

        Round storage round = rounds[currentRound];
        require(round.participants.length + _tickets <= maxTickets, "Exceeds max tickets");

        _addParticipant(msg.sender, _tickets);
        round.prizePool += msg.value;

        emit TicketPurchased(msg.sender, currentRound, _tickets);
    }

    function drawWinner() external onlyOwner lotteryIsActive {
        Round storage round = rounds[currentRound];
        require(block.timestamp >= round.endTime, "Round not ended");
        require(!round.completed, "Already drawn");
        require(round.participants.length > 0, "No participants");

        address winner = _selectWinner();
        uint256 prize = _calculatePrize(round.prizePool);

        round.winner = winner;
        round.completed = true;
        lotteryActive = false;

        _transferPrize(winner, prize);

        emit LotteryDrawn(currentRound, winner, prize);
        emit LotteryEnded(currentRound);

        currentRound++;
    }

    function _addParticipant(address _participant, uint256 _tickets) internal {
        Round storage round = rounds[currentRound];

        for (uint256 i = 0; i < _tickets; i++) {
            round.participants.push(_participant);
        }

        ticketCount[currentRound][_participant] += _tickets;
    }

    function _selectWinner() internal view returns (address) {
        Round storage round = rounds[currentRound];
        uint256 randomIndex = _generateRandom() % round.participants.length;
        return round.participants[randomIndex];
    }

    function _generateRandom() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            rounds[currentRound].participants.length,
            msg.sender
        )));
    }

    function _calculatePrize(uint256 _prizePool) internal pure returns (uint256) {
        return (_prizePool * 90) / 100;
    }

    function _transferPrize(address _winner, uint256 _prize) internal {
        (bool success, ) = payable(_winner).call{value: _prize}("");
        require(success, "Transfer failed");
    }

    function getParticipants(uint256 _round) external view returns (address[] memory) {
        return rounds[_round].participants;
    }

    function getTicketCount(uint256 _round, address _participant) external view returns (uint256) {
        return ticketCount[_round][_participant];
    }

    function getRoundInfo(uint256 _round) external view returns (
        uint256 roundId,
        uint256 participantCount,
        address winner,
        uint256 prizePool
    ) {
        Round storage round = rounds[_round];
        return (
            round.roundId,
            round.participants.length,
            round.winner,
            round.prizePool
        );
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        require(!lotteryActive, "Cannot change during active lottery");
        require(_newPrice > 0, "Invalid price");
        ticketPrice = _newPrice;
    }

    function updateMaxTickets(uint256 _newMax) external onlyOwner {
        require(!lotteryActive, "Cannot change during active lottery");
        require(_newMax > 0, "Invalid max tickets");
        maxTickets = _newMax;
    }
}
