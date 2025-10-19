
pragma solidity ^0.8.0;

contract SecureLottery {
    address public owner;
    address[] public players;
    address public winner;
    uint256 public ticketPrice;
    uint256 public lotteryEndTime;
    bool public lotteryActive;
    uint256 public lotteryId;

    mapping(address => uint256) public playerTicketCount;
    mapping(uint256 => address) public lotteryWinners;

    event PlayerEntered(address indexed player, uint256 ticketCount);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 lotteryId);
    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event LotteryEnded(uint256 indexed lotteryId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive && block.timestamp < lotteryEndTime, "Lottery is not active");
        _;
    }

    modifier lotteryIsInactive() {
        require(!lotteryActive, "Lottery is currently active");
        _;
    }

    constructor() {
        owner = msg.sender;
        lotteryActive = false;
        lotteryId = 0;
    }

    function startLottery(uint256 _ticketPrice, uint256 _duration) external onlyOwner lotteryIsInactive {
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        ticketPrice = _ticketPrice;
        lotteryEndTime = block.timestamp + _duration;
        lotteryActive = true;
        lotteryId++;

        emit LotteryStarted(lotteryId, ticketPrice, lotteryEndTime);
    }

    function buyTickets(uint256 _ticketCount) external payable lotteryIsActive {
        require(_ticketCount > 0, "Must buy at least one ticket");
        require(msg.value == ticketPrice * _ticketCount, "Incorrect payment amount");

        _addPlayerTickets(msg.sender, _ticketCount);
        emit PlayerEntered(msg.sender, _ticketCount);
    }

    function selectWinner() external onlyOwner {
        require(lotteryActive, "No active lottery");
        require(block.timestamp >= lotteryEndTime, "Lottery has not ended yet");
        require(players.length > 0, "No players in lottery");

        address selectedWinner = _generateWinner();
        uint256 prize = _calculatePrize();

        winner = selectedWinner;
        lotteryWinners[lotteryId] = selectedWinner;
        lotteryActive = false;

        _transferPrize(selectedWinner, prize);
        _resetLottery();

        emit WinnerSelected(selectedWinner, prize, lotteryId);
        emit LotteryEnded(lotteryId);
    }

    function getPlayerCount() external view returns (uint256) {
        return players.length;
    }

    function getTotalPrize() external view returns (uint256) {
        return address(this).balance;
    }

    function getTimeRemaining() external view returns (uint256) {
        if (!lotteryActive || block.timestamp >= lotteryEndTime) {
            return 0;
        }
        return lotteryEndTime - block.timestamp;
    }

    function emergencyWithdraw() external onlyOwner lotteryIsInactive {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }

    function _addPlayerTickets(address _player, uint256 _ticketCount) internal {
        if (playerTicketCount[_player] == 0) {
            players.push(_player);
        }

        for (uint256 i = 0; i < _ticketCount; i++) {
            players.push(_player);
        }

        playerTicketCount[_player] += _ticketCount;
    }

    function _generateWinner() internal view returns (address) {
        uint256 randomIndex = _generateRandomNumber() % players.length;
        return players[randomIndex];
    }

    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            players.length,
            msg.sender
        )));
    }

    function _calculatePrize() internal view returns (uint256) {
        uint256 totalBalance = address(this).balance;
        uint256 ownerFee = totalBalance * 5 / 100;
        return totalBalance - ownerFee;
    }

    function _transferPrize(address _winner, uint256 _prize) internal {
        uint256 ownerFee = address(this).balance - _prize;

        payable(owner).transfer(ownerFee);
        payable(_winner).transfer(_prize);
    }

    function _resetLottery() internal {
        delete players;

        for (uint256 i = 0; i < players.length; i++) {
            delete playerTicketCount[players[i]];
        }

        winner = address(0);
        ticketPrice = 0;
        lotteryEndTime = 0;
    }
}
