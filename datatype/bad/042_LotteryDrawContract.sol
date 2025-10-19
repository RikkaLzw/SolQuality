
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

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public playerTickets;
    mapping(uint256 => address) public roundWinners;

    event TicketPurchased(address indexed player, uint256 ticketNumber, string ticketId);
    event LotteryDrawn(uint256 indexed round, address winner, uint256 prize);
    event LotteryStarted(uint256 indexed round, uint256 ticketPrice, uint256 maxTickets);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryActive() {
        require(uint8(lotteryStatus) == uint8(1), "Lottery is not active");
        _;
    }

    constructor(string memory _name, uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        lotteryName = _name;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        currentRound = uint256(1);
        lotteryStatus = uint256(0);
    }

    function startLottery() external onlyOwner {
        require(uint8(lotteryStatus) == uint8(0), "Lottery already active");

        lotteryStatus = uint256(1);
        ticketsSold = uint256(0);

        emit LotteryStarted(currentRound, ticketPrice, maxTickets);
    }

    function buyTicket() external payable lotteryActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(ticketsSold < maxTickets, "All tickets sold");

        uint256 ticketNumber = ticketsSold + uint256(1);
        string memory ticketId = string(abi.encodePacked("TICKET_", toString(ticketNumber)));

        tickets[ticketNumber] = Ticket({
            player: msg.sender,
            ticketNumber: ticketNumber,
            ticketId: ticketId,
            purchaseTime: block.timestamp,
            isValid: uint256(1)
        });

        playerTickets[msg.sender].push(ticketNumber);
        ticketsSold = uint256(ticketsSold + 1);

        emit TicketPurchased(msg.sender, ticketNumber, ticketId);

        if (ticketsSold == maxTickets) {
            lotteryStatus = uint256(2);
        }
    }

    function drawWinner() external onlyOwner {
        require(uint8(lotteryStatus) == uint8(2), "Cannot draw winner yet");
        require(ticketsSold > uint256(0), "No tickets sold");

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            ticketsSold
        ))) % ticketsSold;

        uint256 winningTicket = randomNumber + uint256(1);
        address winner = tickets[winningTicket].player;

        require(uint8(tickets[winningTicket].isValid) == uint8(1), "Invalid winning ticket");

        roundWinners[currentRound] = winner;
        winnerData = abi.encodePacked("WINNER_ROUND_", toString(currentRound), "_TICKET_", toString(winningTicket));

        uint256 prize = address(this).balance;

        lotteryStatus = uint256(0);
        currentRound = uint256(currentRound + 1);

        payable(winner).transfer(prize);

        emit LotteryDrawn(currentRound - uint256(1), winner, prize);
    }

    function getPlayerTickets(address player) external view returns (uint256[] memory) {
        return playerTickets[player];
    }

    function getTicketInfo(uint256 ticketNumber) external view returns (
        address player,
        string memory ticketId,
        uint256 purchaseTime,
        uint256 isValid
    ) {
        Ticket memory ticket = tickets[ticketNumber];
        return (ticket.player, ticket.ticketId, ticket.purchaseTime, ticket.isValid);
    }

    function getLotteryInfo() external view returns (
        uint256 _currentRound,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _ticketsSold,
        uint256 _status,
        string memory _name
    ) {
        return (currentRound, ticketPrice, maxTickets, ticketsSold, lotteryStatus, lotteryName);
    }

    function getWinnerData() external view returns (bytes memory) {
        return winnerData;
    }

    function emergencyWithdraw() external onlyOwner {
        require(uint8(lotteryStatus) == uint8(0), "Cannot withdraw during active lottery");
        payable(owner).transfer(address(this).balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
