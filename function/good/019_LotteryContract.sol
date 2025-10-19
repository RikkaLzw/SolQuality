
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    address public winner;
    uint256 public ticketPrice;
    uint256 public lotteryEndTime;
    uint256 public maxTickets;
    bool public lotteryActive;

    address[] public participants;
    mapping(address => uint256) public ticketCount;

    event TicketPurchased(address indexed buyer, uint256 amount);
    event LotteryEnded(address indexed winner, uint256 prize);
    event LotteryStarted(uint256 ticketPrice, uint256 endTime, uint256 maxTickets);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        require(block.timestamp < lotteryEndTime, "Lottery has ended");
        _;
    }

    constructor() {
        owner = msg.sender;
        lotteryActive = false;
    }

    function startLottery(uint256 _ticketPrice, uint256 _duration, uint256 _maxTickets) external onlyOwner {
        require(!lotteryActive, "Lottery is already active");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_maxTickets > 0, "Max tickets must be greater than 0");

        ticketPrice = _ticketPrice;
        lotteryEndTime = block.timestamp + _duration;
        maxTickets = _maxTickets;
        lotteryActive = true;

        _resetLottery();

        emit LotteryStarted(_ticketPrice, lotteryEndTime, _maxTickets);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(participants.length < maxTickets, "Maximum tickets sold");

        participants.push(msg.sender);
        ticketCount[msg.sender]++;

        emit TicketPurchased(msg.sender, 1);
    }

    function endLottery() external {
        require(lotteryActive, "Lottery is not active");
        require(
            block.timestamp >= lotteryEndTime || participants.length == maxTickets,
            "Lottery cannot be ended yet"
        );
        require(participants.length > 0, "No participants");

        winner = _selectWinner();
        uint256 prize = _calculatePrize();

        lotteryActive = false;

        _transferPrize(prize);

        emit LotteryEnded(winner, prize);
    }

    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }

    function getTotalPrize() external view returns (uint256) {
        return address(this).balance;
    }

    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= lotteryEndTime) {
            return 0;
        }
        return lotteryEndTime - block.timestamp;
    }

    function withdrawOwnerFee() external onlyOwner {
        require(!lotteryActive, "Cannot withdraw during active lottery");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner).transfer(balance);
    }

    function _selectWinner() private view returns (address) {
        uint256 randomIndex = _generateRandomNumber() % participants.length;
        return participants[randomIndex];
    }

    function _generateRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            participants.length,
            msg.sender
        )));
    }

    function _calculatePrize() private view returns (uint256) {
        uint256 totalPool = address(this).balance;
        uint256 ownerFee = totalPool * 10 / 100;
        return totalPool - ownerFee;
    }

    function _transferPrize(uint256 prize) private {
        payable(winner).transfer(prize);
    }

    function _resetLottery() private {
        delete participants;
        winner = address(0);


        for (uint256 i = 0; i < participants.length; i++) {
            ticketCount[participants[i]] = 0;
        }
    }
}
