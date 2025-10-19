
pragma solidity ^0.8.19;

contract SecureLottery {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    bool public lotteryActive;

    struct Round {
        uint256 totalPrize;
        uint256 ticketsSold;
        address winner;
        bool completed;
        uint256 endTime;
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(uint256 => address)) public ticketHolders;
    mapping(uint256 => mapping(address => uint256)) public playerTicketCount;

    event TicketPurchased(address indexed player, uint256 indexed round, uint256 ticketNumber);
    event WinnerSelected(address indexed winner, uint256 indexed round, uint256 prize);
    event LotteryStarted(uint256 indexed round, uint256 ticketPrice, uint256 maxTickets);
    event LotteryEnded(uint256 indexed round);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery not active");
        _;
    }

    modifier validTicketPrice(uint256 price) {
        require(price > 0, "Invalid ticket price");
        _;
    }

    modifier validMaxTickets(uint256 max) {
        require(max > 0 && max <= 1000, "Invalid max tickets");
        _;
    }

    constructor() {
        owner = msg.sender;
        currentRound = 0;
        lotteryActive = false;
    }

    function startLottery(uint256 _ticketPrice, uint256 _maxTickets)
        external
        onlyOwner
        validTicketPrice(_ticketPrice)
        validMaxTickets(_maxTickets)
    {
        require(!lotteryActive, "Lottery already active");

        currentRound++;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryActive = true;

        rounds[currentRound] = Round({
            totalPrize: 0,
            ticketsSold: 0,
            winner: address(0),
            completed: false,
            endTime: block.timestamp + 7 days
        });

        emit LotteryStarted(currentRound, _ticketPrice, _maxTickets);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect payment amount");
        require(rounds[currentRound].ticketsSold < maxTickets, "All tickets sold");
        require(block.timestamp < rounds[currentRound].endTime, "Lottery expired");

        uint256 ticketNumber = rounds[currentRound].ticketsSold + 1;

        ticketHolders[currentRound][ticketNumber] = msg.sender;
        playerTicketCount[currentRound][msg.sender]++;
        rounds[currentRound].ticketsSold++;
        rounds[currentRound].totalPrize += msg.value;

        emit TicketPurchased(msg.sender, currentRound, ticketNumber);

        if (rounds[currentRound].ticketsSold == maxTickets) {
            _selectWinner();
        }
    }

    function endLottery() external onlyOwner lotteryIsActive {
        require(rounds[currentRound].ticketsSold > 0, "No tickets sold");
        require(
            block.timestamp >= rounds[currentRound].endTime ||
            rounds[currentRound].ticketsSold == maxTickets,
            "Cannot end lottery yet"
        );

        _selectWinner();
    }

    function _selectWinner() internal {
        uint256 winningTicket = _generateRandomNumber() % rounds[currentRound].ticketsSold + 1;
        address winner = ticketHolders[currentRound][winningTicket];

        rounds[currentRound].winner = winner;
        rounds[currentRound].completed = true;
        lotteryActive = false;

        uint256 prize = _calculatePrize();
        uint256 fee = rounds[currentRound].totalPrize - prize;

        _transferPrize(winner, prize);
        _transferFee(fee);

        emit WinnerSelected(winner, currentRound, prize);
        emit LotteryEnded(currentRound);
    }

    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            rounds[currentRound].ticketsSold
        )));
    }

    function _calculatePrize() internal view returns (uint256) {
        return (rounds[currentRound].totalPrize * 90) / 100;
    }

    function _transferPrize(address winner, uint256 amount) internal {
        (bool success, ) = payable(winner).call{value: amount}("");
        require(success, "Prize transfer failed");
    }

    function _transferFee(uint256 amount) internal {
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Fee transfer failed");
    }

    function getCurrentRoundInfo() external view returns (
        uint256 totalPrize,
        uint256 ticketsSold,
        uint256 timeLeft
    ) {
        Round memory round = rounds[currentRound];
        totalPrize = round.totalPrize;
        ticketsSold = round.ticketsSold;

        if (block.timestamp >= round.endTime) {
            timeLeft = 0;
        } else {
            timeLeft = round.endTime - block.timestamp;
        }
    }

    function getPlayerTickets(address player) external view returns (uint256) {
        return playerTicketCount[currentRound][player];
    }

    function getRoundWinner(uint256 roundId) external view returns (address) {
        return rounds[roundId].winner;
    }

    function emergencyWithdraw() external onlyOwner {
        require(!lotteryActive, "Cannot withdraw during active lottery");

        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }
}
