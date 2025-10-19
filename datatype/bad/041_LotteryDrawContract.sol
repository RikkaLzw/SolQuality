
pragma solidity ^0.8.0;

contract LotteryDrawContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    uint256 public ticketsSold;
    uint256 public isActive;

    string public lotteryId;
    bytes public winnerData;

    struct Ticket {
        address player;
        uint256 ticketNumber;
        uint256 isPaid;
        string ticketId;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256) public playerTicketCount;

    uint256[] public ticketNumbers;
    address[] public players;

    event TicketPurchased(address indexed player, uint256 ticketNumber, string ticketId);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 round);
    event LotteryReset(uint256 newRound);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryActive() {
        require(isActive == uint256(1), "Lottery is not active");
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets, string memory _lotteryId) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryId = _lotteryId;
        currentRound = uint256(1);
        isActive = uint256(1);
        ticketsSold = uint256(0);
    }

    function buyTicket(string memory _ticketId) external payable lotteryActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(ticketsSold < maxTickets, "All tickets sold");
        require(playerTicketCount[msg.sender] < uint256(5), "Maximum 5 tickets per player");

        uint256 ticketNumber = ticketsSold + uint256(1);

        tickets[ticketNumber] = Ticket({
            player: msg.sender,
            ticketNumber: ticketNumber,
            isPaid: uint256(1),
            ticketId: _ticketId
        });

        ticketNumbers.push(ticketNumber);
        players.push(msg.sender);
        playerTicketCount[msg.sender] += uint256(1);
        ticketsSold += uint256(1);

        emit TicketPurchased(msg.sender, ticketNumber, _ticketId);

        if (ticketsSold == maxTickets) {
            selectWinner();
        }
    }

    function selectWinner() internal {
        require(ticketsSold > uint256(0), "No tickets sold");

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            ticketsSold
        ))) % ticketsSold;

        uint256 winningTicketNumber = ticketNumbers[randomIndex];
        address winner = tickets[winningTicketNumber].player;
        uint256 prize = address(this).balance;


        winnerData = abi.encodePacked(winner, winningTicketNumber, prize, currentRound);

        payable(winner).transfer(prize);

        emit WinnerSelected(winner, prize, currentRound);

        resetLottery();
    }

    function resetLottery() internal {

        for (uint256 i = uint256(0); i < ticketNumbers.length; i++) {
            delete tickets[ticketNumbers[i]];
        }

        for (uint256 i = uint256(0); i < players.length; i++) {
            playerTicketCount[players[i]] = uint256(0);
        }

        delete ticketNumbers;
        delete players;

        ticketsSold = uint256(0);
        currentRound += uint256(1);

        emit LotteryReset(currentRound);
    }

    function emergencySelectWinner() external onlyOwner lotteryActive {
        require(ticketsSold > uint256(0), "No tickets to draw from");
        selectWinner();
    }

    function setLotteryStatus(uint256 _status) external onlyOwner {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        isActive = _status;
    }

    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        require(isActive == uint256(0), "Cannot change price while active");
        ticketPrice = _newPrice;
    }

    function getTicketInfo(uint256 _ticketNumber) external view returns (
        address player,
        uint256 ticketNumber,
        uint256 isPaid,
        string memory ticketId
    ) {
        Ticket memory ticket = tickets[_ticketNumber];
        return (ticket.player, ticket.ticketNumber, ticket.isPaid, ticket.ticketId);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getWinnerData() external view returns (bytes memory) {
        return winnerData;
    }

    function isLotteryActive() external view returns (uint256) {
        return isActive;
    }

    function getRemainingTickets() external view returns (uint256) {
        return maxTickets - ticketsSold;
    }
}
