
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
        uint256 totalPrize;
        address winner;
        uint256 winningNumber;
        string roundStatus;
        uint256 isCompleted;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public playerTickets;
    mapping(uint256 => Round) public rounds;
    mapping(address => uint256) public playerWinnings;

    event TicketPurchased(address indexed player, uint256 ticketNumber, string ticketId);
    event LotteryDrawn(uint256 indexed round, address winner, uint256 prize);
    event PrizeWithdrawn(address indexed winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryActive() {
        require(lotteryStatus == uint256(1), "Lottery is not active");
        _;
    }

    constructor(
        uint256 _ticketPrice,
        uint256 _maxTickets,
        string memory _lotteryName
    ) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryName = _lotteryName;
        currentRound = uint256(1);
        ticketsSold = uint256(0);
        lotteryStatus = uint256(0);
    }

    function startLottery() external onlyOwner {
        require(lotteryStatus == uint256(0), "Lottery already active");
        lotteryStatus = uint256(1);
        ticketsSold = uint256(0);

        rounds[currentRound] = Round({
            roundId: currentRound,
            totalPrize: uint256(0),
            winner: address(0),
            winningNumber: uint256(0),
            roundStatus: "ACTIVE",
            isCompleted: uint256(0)
        });
    }

    function buyTicket(string memory _ticketId) external payable lotteryActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(ticketsSold < maxTickets, "All tickets sold");
        require(bytes(_ticketId).length > 0, "Ticket ID cannot be empty");

        uint256 ticketNumber = ticketsSold + uint256(1);

        tickets[ticketNumber] = Ticket({
            player: msg.sender,
            ticketNumber: ticketNumber,
            ticketId: _ticketId,
            purchaseTime: block.timestamp,
            isValid: uint256(1)
        });

        playerTickets[msg.sender].push(ticketNumber);
        ticketsSold = uint256(ticketsSold + 1);
        rounds[currentRound].totalPrize += msg.value;

        emit TicketPurchased(msg.sender, ticketNumber, _ticketId);
    }

    function drawWinner() external onlyOwner {
        require(lotteryStatus == uint256(1), "Lottery not active");
        require(ticketsSold > uint256(0), "No tickets sold");

        lotteryStatus = uint256(2);

        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    msg.sender,
                    ticketsSold
                )
            )
        );

        uint256 winningTicketNumber = (randomNumber % ticketsSold) + uint256(1);
        address winner = tickets[winningTicketNumber].player;
        uint256 prize = rounds[currentRound].totalPrize;

        rounds[currentRound].winner = winner;
        rounds[currentRound].winningNumber = winningTicketNumber;
        rounds[currentRound].roundStatus = "COMPLETED";
        rounds[currentRound].isCompleted = uint256(1);

        playerWinnings[winner] += prize;

        winnerData = abi.encodePacked(
            "Round: ",
            uint256ToString(currentRound),
            " Winner: ",
            addressToString(winner),
            " Ticket: ",
            uint256ToString(winningTicketNumber)
        );

        emit LotteryDrawn(currentRound, winner, prize);

        lotteryStatus = uint256(0);
        currentRound = uint256(currentRound + 1);
    }

    function withdrawPrize() external {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > uint256(0), "No winnings to withdraw");

        playerWinnings[msg.sender] = uint256(0);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit PrizeWithdrawn(msg.sender, amount);
    }

    function getPlayerTickets(address _player) external view returns (uint256[] memory) {
        return playerTickets[_player];
    }

    function getTicketDetails(uint256 _ticketNumber) external view returns (
        address player,
        string memory ticketId,
        uint256 purchaseTime,
        uint256 isValid
    ) {
        Ticket memory ticket = tickets[_ticketNumber];
        return (ticket.player, ticket.ticketId, ticket.purchaseTime, ticket.isValid);
    }

    function getRoundDetails(uint256 _roundId) external view returns (
        uint256 totalPrize,
        address winner,
        uint256 winningNumber,
        string memory roundStatus,
        uint256 isCompleted
    ) {
        Round memory round = rounds[_roundId];
        return (
            round.totalPrize,
            round.winner,
            round.winningNumber,
            round.roundStatus,
            round.isCompleted
        );
    }

    function emergencyStop() external onlyOwner {
        lotteryStatus = uint256(0);
    }

    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        require(lotteryStatus == uint256(0), "Cannot change price during active lottery");
        ticketPrice = _newPrice;
    }

    function updateMaxTickets(uint256 _newMax) external onlyOwner {
        require(lotteryStatus == uint256(0), "Cannot change max tickets during active lottery");
        maxTickets = _newMax;
    }

    function uint256ToString(uint256 value) internal pure returns (string memory) {
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

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
