
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    address public winner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public ticketsSold;
    uint256 public lotteryId;
    bool public lotteryActive;
    uint256 public endTime;

    mapping(uint256 => address) public tickets;
    mapping(address => uint256) public playerTicketCount;
    address[] public players;

    event LotteryStarted(
        uint256 indexed lotteryId,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 endTime
    );

    event TicketPurchased(
        address indexed player,
        uint256 indexed ticketNumber,
        uint256 indexed lotteryId
    );

    event WinnerSelected(
        address indexed winner,
        uint256 indexed lotteryId,
        uint256 prizeAmount
    );

    event LotteryEnded(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 totalTickets
    );

    event PrizeWithdrawn(
        address indexed winner,
        uint256 amount,
        uint256 indexed lotteryId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        require(block.timestamp < endTime, "Lottery has expired");
        _;
    }

    modifier lotteryNotActive() {
        require(!lotteryActive, "Lottery is currently active");
        _;
    }

    constructor() {
        owner = msg.sender;
        lotteryId = 0;
        lotteryActive = false;
    }

    function startLottery(
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _duration
    ) external onlyOwner lotteryNotActive {
        require(_ticketPrice > 0, "Ticket price must be greater than zero");
        require(_maxTickets > 0, "Max tickets must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");

        lotteryId++;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        ticketsSold = 0;
        lotteryActive = true;
        endTime = block.timestamp + _duration;
        winner = address(0);


        for (uint256 i = 0; i < players.length; i++) {
            playerTicketCount[players[i]] = 0;
        }
        delete players;

        emit LotteryStarted(lotteryId, ticketPrice, maxTickets, endTime);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect ticket price sent");
        require(ticketsSold < maxTickets, "All tickets have been sold");

        tickets[ticketsSold] = msg.sender;

        if (playerTicketCount[msg.sender] == 0) {
            players.push(msg.sender);
        }
        playerTicketCount[msg.sender]++;

        emit TicketPurchased(msg.sender, ticketsSold, lotteryId);

        ticketsSold++;

        if (ticketsSold == maxTickets) {
            _selectWinner();
        }
    }

    function selectWinner() external onlyOwner {
        require(lotteryActive, "Lottery is not active");
        require(
            block.timestamp >= endTime || ticketsSold == maxTickets,
            "Lottery conditions not met for winner selection"
        );
        require(ticketsSold > 0, "No tickets sold");

        _selectWinner();
    }

    function _selectWinner() private {
        require(ticketsSold > 0, "No tickets to select winner from");

        uint256 randomIndex = _generateRandomNumber() % ticketsSold;
        winner = tickets[randomIndex];
        lotteryActive = false;

        uint256 prizeAmount = address(this).balance;

        emit WinnerSelected(winner, lotteryId, prizeAmount);
        emit LotteryEnded(lotteryId, winner, ticketsSold);
    }

    function withdrawPrize() external {
        require(winner != address(0), "No winner selected yet");
        require(msg.sender == winner, "Only winner can withdraw prize");
        require(address(this).balance > 0, "No prize to withdraw");

        uint256 prizeAmount = address(this).balance;

        (bool success, ) = payable(winner).call{value: prizeAmount}("");
        require(success, "Prize transfer failed");

        emit PrizeWithdrawn(winner, prizeAmount, lotteryId);
    }

    function _generateRandomNumber() private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    msg.sender,
                    ticketsSold,
                    blockhash(block.number - 1)
                )
            )
        );
    }

    function emergencyEndLottery() external onlyOwner {
        require(lotteryActive, "Lottery is not active");

        lotteryActive = false;


        for (uint256 i = 0; i < ticketsSold; i++) {
            address player = tickets[i];
            (bool success, ) = payable(player).call{value: ticketPrice}("");
            require(success, "Refund failed");
        }

        emit LotteryEnded(lotteryId, address(0), ticketsSold);
    }

    function getLotteryInfo() external view returns (
        uint256 currentLotteryId,
        bool isActive,
        uint256 currentTicketPrice,
        uint256 currentMaxTickets,
        uint256 currentTicketsSold,
        uint256 currentEndTime,
        address currentWinner,
        uint256 prizePool
    ) {
        return (
            lotteryId,
            lotteryActive,
            ticketPrice,
            maxTickets,
            ticketsSold,
            endTime,
            winner,
            address(this).balance
        );
    }

    function getPlayerTickets(address player) external view returns (uint256) {
        return playerTicketCount[player];
    }

    function getTotalPlayers() external view returns (uint256) {
        return players.length;
    }

    receive() external payable {
        revert("Direct payments not allowed, use buyTicket function");
    }

    fallback() external payable {
        revert("Function not found, use buyTicket to participate");
    }
}
