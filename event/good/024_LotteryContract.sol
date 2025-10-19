
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public ticketsSold;
    uint256 public lotteryId;
    bool public lotteryActive;

    mapping(uint256 => address) public tickets;
    mapping(address => uint256[]) public playerTickets;
    mapping(uint256 => address) public lotteryWinners;
    mapping(uint256 => uint256) public lotteryPrizes;

    event LotteryStarted(
        uint256 indexed lotteryId,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 timestamp
    );

    event TicketPurchased(
        uint256 indexed lotteryId,
        address indexed player,
        uint256 indexed ticketNumber,
        uint256 timestamp
    );

    event WinnerDrawn(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 indexed winningTicket,
        uint256 prizeAmount,
        uint256 timestamp
    );

    event PrizeWithdrawn(
        uint256 indexed lotteryId,
        address indexed winner,
        uint256 amount,
        uint256 timestamp
    );

    event LotteryEnded(
        uint256 indexed lotteryId,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "No active lottery");
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

    function startLottery(uint256 _ticketPrice, uint256 _maxTickets)
        external
        onlyOwner
        lotteryNotActive
    {
        require(_ticketPrice > 0, "Ticket price must be greater than zero");
        require(_maxTickets > 1, "Must allow at least 2 tickets");
        require(_maxTickets <= 10000, "Maximum 10000 tickets allowed");

        lotteryId++;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        ticketsSold = 0;
        lotteryActive = true;

        emit LotteryStarted(lotteryId, _ticketPrice, _maxTickets, block.timestamp);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect ticket price sent");
        require(ticketsSold < maxTickets, "All tickets have been sold");

        uint256 ticketNumber = ticketsSold;
        tickets[ticketNumber] = msg.sender;
        playerTickets[msg.sender].push(ticketNumber);
        ticketsSold++;

        emit TicketPurchased(lotteryId, msg.sender, ticketNumber, block.timestamp);
    }

    function drawWinner() external onlyOwner lotteryIsActive {
        require(ticketsSold > 0, "No tickets have been sold");

        uint256 winningTicket = _generateRandomNumber() % ticketsSold;
        address winner = tickets[winningTicket];
        uint256 prizeAmount = address(this).balance;

        lotteryWinners[lotteryId] = winner;
        lotteryPrizes[lotteryId] = prizeAmount;
        lotteryActive = false;

        emit WinnerDrawn(lotteryId, winner, winningTicket, prizeAmount, block.timestamp);
        emit LotteryEnded(lotteryId, block.timestamp);
    }

    function withdrawPrize(uint256 _lotteryId) external {
        require(lotteryWinners[_lotteryId] == msg.sender, "You are not the winner of this lottery");
        require(lotteryPrizes[_lotteryId] > 0, "Prize has already been withdrawn");

        uint256 prizeAmount = lotteryPrizes[_lotteryId];
        lotteryPrizes[_lotteryId] = 0;

        (bool success, ) = payable(msg.sender).call{value: prizeAmount}("");
        require(success, "Prize transfer failed");

        emit PrizeWithdrawn(_lotteryId, msg.sender, prizeAmount, block.timestamp);
    }

    function emergencyEndLottery() external onlyOwner lotteryIsActive {
        lotteryActive = false;


        for (uint256 i = 0; i < ticketsSold; i++) {
            address player = tickets[i];
            (bool success, ) = payable(player).call{value: ticketPrice}("");
            require(success, "Refund failed");
        }

        emit LotteryEnded(lotteryId, block.timestamp);
    }

    function getPlayerTickets(address player) external view returns (uint256[] memory) {
        return playerTickets[player];
    }

    function getCurrentLotteryInfo() external view returns (
        uint256 currentLotteryId,
        uint256 currentTicketPrice,
        uint256 currentMaxTickets,
        uint256 currentTicketsSold,
        bool isActive,
        uint256 currentPrizePool
    ) {
        return (
            lotteryId,
            ticketPrice,
            maxTickets,
            ticketsSold,
            lotteryActive,
            address(this).balance
        );
    }

    function getLotteryWinner(uint256 _lotteryId) external view returns (address) {
        return lotteryWinners[_lotteryId];
    }

    function getLotteryPrize(uint256 _lotteryId) external view returns (uint256) {
        return lotteryPrizes[_lotteryId];
    }

    function _generateRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            ticketsSold
        )));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(!lotteryActive, "Cannot transfer ownership during active lottery");

        owner = newOwner;
    }

    receive() external payable {
        revert("Direct payments not accepted. Use buyTicket() function");
    }

    fallback() external payable {
        revert("Function does not exist. Use buyTicket() to participate");
    }
}
