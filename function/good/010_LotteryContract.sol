
pragma solidity ^0.8.19;

contract LotteryContract {
    address public owner;
    address public winner;
    address[] public players;

    uint256 public ticketPrice;
    uint256 public lotteryId;
    uint256 public endTime;

    bool public lotteryActive;

    mapping(uint256 => address) public lotteryHistory;

    event TicketPurchased(address indexed player, uint256 lotteryId);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 lotteryId);
    event LotteryStarted(uint256 lotteryId, uint256 ticketPrice, uint256 endTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        require(block.timestamp < endTime, "Lottery has ended");
        _;
    }

    constructor() {
        owner = msg.sender;
        lotteryId = 1;
        lotteryActive = false;
    }

    function startLottery(uint256 _ticketPrice, uint256 _duration) external onlyOwner {
        require(!lotteryActive, "Lottery already active");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        ticketPrice = _ticketPrice;
        endTime = block.timestamp + _duration;
        lotteryActive = true;
        delete players;
        winner = address(0);

        emit LotteryStarted(lotteryId, ticketPrice, endTime);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(msg.sender != owner, "Owner cannot participate");

        players.push(msg.sender);
        emit TicketPurchased(msg.sender, lotteryId);
    }

    function selectWinner() external onlyOwner {
        require(lotteryActive, "Lottery is not active");
        require(block.timestamp >= endTime, "Lottery has not ended yet");
        require(players.length > 0, "No players in lottery");

        uint256 winnerIndex = _generateRandomNumber() % players.length;
        winner = players[winnerIndex];
        lotteryHistory[lotteryId] = winner;

        uint256 prize = address(this).balance;
        lotteryActive = false;

        _transferPrize(winner, prize);

        emit WinnerSelected(winner, prize, lotteryId);
        lotteryId++;
    }

    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    function getPlayerCount() external view returns (uint256) {
        return players.length;
    }

    function getPrizePool() external view returns (uint256) {
        return address(this).balance;
    }

    function getLotteryInfo() external view returns (
        uint256 currentLotteryId,
        uint256 currentTicketPrice,
        uint256 currentEndTime,
        bool isActive
    ) {
        return (lotteryId, ticketPrice, endTime, lotteryActive);
    }

    function emergencyStop() external onlyOwner {
        require(lotteryActive, "Lottery is not active");
        lotteryActive = false;
        _refundPlayers();
    }

    function _generateRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            players.length,
            blockhash(block.number - 1)
        )));
    }

    function _transferPrize(address _winner, uint256 _amount) private {
        (bool success, ) = _winner.call{value: _amount}("");
        require(success, "Prize transfer failed");
    }

    function _refundPlayers() private {
        uint256 refundAmount = ticketPrice;
        for (uint256 i = 0; i < players.length; i++) {
            (bool success, ) = players[i].call{value: refundAmount}("");
            require(success, "Refund failed");
        }
    }
}
