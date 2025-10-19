
pragma solidity ^0.8.0;

contract LotteryDrawContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    uint256 public ticketsSold;
    uint256 public lotteryStatus;

    string public lotteryName;
    bytes public winnerData;

    struct Ticket {
        address player;
        uint256 ticketNumber;
        string ticketId;
        uint256 purchaseTime;
        uint256 isValid;
    }

    struct Round {
        uint256 roundId;
        uint256 startTime;
        uint256 endTime;
        address winner;
        uint256 prizeAmount;
        uint256 totalTickets;
        string roundName;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public playerTickets;
    mapping(uint256 => Round) public rounds;
    mapping(address => uint256) public playerWinCount;

    uint256[] public allTicketNumbers;
    address[] public allPlayers;

    event TicketPurchased(address indexed player, uint256 ticketNumber, string ticketId);
    event WinnerSelected(address indexed winner, uint256 prizeAmount, uint256 roundId);
    event RoundStarted(uint256 roundId, string roundName);
    event RoundEnded(uint256 roundId, address winner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryActive() {
        require(uint8(lotteryStatus) == 1, "Lottery is not active");
        _;
    }

    constructor(
        string memory _lotteryName,
        uint256 _ticketPrice,
        uint256 _maxTickets
    ) {
        owner = msg.sender;
        lotteryName = _lotteryName;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        currentRound = uint256(1);
        lotteryStatus = uint256(0);
        ticketsSold = uint256(0);
    }

    function startNewRound(string memory _roundName) external onlyOwner {
        require(uint8(lotteryStatus) == 0, "Previous round not finished");

        currentRound = uint256(currentRound + 1);
        lotteryStatus = uint256(1);
        ticketsSold = uint256(0);

        rounds[currentRound] = Round({
            roundId: currentRound,
            startTime: uint256(block.timestamp),
            endTime: uint256(0),
            winner: address(0),
            prizeAmount: uint256(0),
            totalTickets: uint256(0),
            roundName: _roundName
        });

        delete allTicketNumbers;
        delete allPlayers;

        emit RoundStarted(currentRound, _roundName);
    }

    function buyTicket(string memory _customId) external payable lotteryActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(ticketsSold < maxTickets, "All tickets sold");

        uint256 newTicketNumber = uint256(ticketsSold + 1);
        string memory ticketId = string(abi.encodePacked("TICKET_", _customId));

        tickets[newTicketNumber] = Ticket({
            player: msg.sender,
            ticketNumber: newTicketNumber,
            ticketId: ticketId,
            purchaseTime: uint256(block.timestamp),
            isValid: uint256(1)
        });

        playerTickets[msg.sender].push(newTicketNumber);
        allTicketNumbers.push(newTicketNumber);
        allPlayers.push(msg.sender);

        ticketsSold = uint256(ticketsSold + 1);

        emit TicketPurchased(msg.sender, newTicketNumber, ticketId);
    }

    function drawWinner() external onlyOwner lotteryActive {
        require(ticketsSold > 0, "No tickets sold");

        lotteryStatus = uint256(2);

        uint256 randomIndex = uint256(
            uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.difficulty,
                msg.sender,
                ticketsSold
            ))) % ticketsSold
        );

        uint256 winningTicketNumber = allTicketNumbers[randomIndex];
        address winner = tickets[winningTicketNumber].player;
        uint256 prizeAmount = uint256(address(this).balance);

        rounds[currentRound].winner = winner;
        rounds[currentRound].prizeAmount = prizeAmount;
        rounds[currentRound].totalTickets = ticketsSold;
        rounds[currentRound].endTime = uint256(block.timestamp);

        playerWinCount[winner] = uint256(playerWinCount[winner] + 1);

        bytes memory winnerInfo = abi.encodePacked(
            "Winner: ",
            winner,
            " Ticket: ",
            winningTicketNumber,
            " Round: ",
            currentRound
        );
        winnerData = winnerInfo;

        payable(winner).transfer(prizeAmount);

        lotteryStatus = uint256(0);

        emit WinnerSelected(winner, prizeAmount, currentRound);
        emit RoundEnded(currentRound, winner);
    }

    function getPlayerTickets(address _player) external view returns (uint256[] memory) {
        return playerTickets[_player];
    }

    function getTicketInfo(uint256 _ticketNumber) external view returns (
        address player,
        string memory ticketId,
        uint256 purchaseTime,
        bool isValid
    ) {
        Ticket memory ticket = tickets[_ticketNumber];
        return (
            ticket.player,
            ticket.ticketId,
            ticket.purchaseTime,
            uint8(ticket.isValid) == 1
        );
    }

    function getRoundInfo(uint256 _roundId) external view returns (
        uint256 startTime,
        uint256 endTime,
        address winner,
        uint256 prizeAmount,
        uint256 totalTickets,
        string memory roundName
    ) {
        Round memory round = rounds[_roundId];
        return (
            round.startTime,
            round.endTime,
            round.winner,
            round.prizeAmount,
            round.totalTickets,
            round.roundName
        );
    }

    function getLotteryStatus() external view returns (
        bool isActive,
        uint256 currentTicketsSold,
        uint256 maxTicketsAvailable,
        uint256 currentPrizePool
    ) {
        return (
            uint8(lotteryStatus) == 1,
            ticketsSold,
            maxTickets,
            uint256(address(this).balance)
        );
    }

    function emergencyWithdraw() external onlyOwner {
        require(uint8(lotteryStatus) == 0, "Cannot withdraw during active lottery");
        payable(owner).transfer(address(this).balance);
    }

    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        require(uint8(lotteryStatus) == 0, "Cannot change price during active lottery");
        ticketPrice = _newPrice;
    }

    function updateMaxTickets(uint256 _newMax) external onlyOwner {
        require(uint8(lotteryStatus) == 0, "Cannot change max tickets during active lottery");
        maxTickets = _newMax;
    }
}
