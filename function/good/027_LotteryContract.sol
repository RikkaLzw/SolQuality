
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
    mapping(address => bool) public hasParticipated;

    event TicketPurchased(address indexed buyer, uint256 amount);
    event LotteryEnded(address indexed winner, uint256 prize);
    event LotteryStarted(uint256 endTime, uint256 ticketPrice, uint256 maxTickets);

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

    function startLottery(
        uint256 _duration,
        uint256 _ticketPrice,
        uint256 _maxTickets
    ) external onlyOwner {
        require(!lotteryActive, "Lottery already active");
        require(_duration > 0, "Duration must be positive");
        require(_ticketPrice > 0, "Ticket price must be positive");
        require(_maxTickets > 0, "Max tickets must be positive");

        lotteryEndTime = block.timestamp + _duration;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryActive = true;

        _resetLottery();

        emit LotteryStarted(lotteryEndTime, ticketPrice, maxTickets);
    }

    function buyTickets(uint256 _amount) external payable lotteryIsActive {
        require(_amount > 0, "Amount must be positive");
        require(msg.value == ticketPrice * _amount, "Incorrect payment amount");
        require(participants.length + _amount <= maxTickets, "Exceeds max tickets");

        _addParticipant(_amount);

        emit TicketPurchased(msg.sender, _amount);
    }

    function endLottery() external onlyOwner {
        require(lotteryActive, "Lottery not active");
        require(
            block.timestamp >= lotteryEndTime || participants.length == maxTickets,
            "Lottery cannot be ended yet"
        );

        lotteryActive = false;

        if (participants.length > 0) {
            winner = _selectWinner();
            uint256 prize = address(this).balance;

            (bool success, ) = winner.call{value: prize}("");
            require(success, "Prize transfer failed");

            emit LotteryEnded(winner, prize);
        }
    }

    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTimeRemaining() external view returns (uint256) {
        if (!lotteryActive || block.timestamp >= lotteryEndTime) {
            return 0;
        }
        return lotteryEndTime - block.timestamp;
    }

    function getUserTickets(address _user) external view returns (uint256) {
        return ticketCount[_user];
    }

    function _addParticipant(uint256 _amount) internal {
        for (uint256 i = 0; i < _amount; i++) {
            participants.push(msg.sender);
        }

        ticketCount[msg.sender] += _amount;
        hasParticipated[msg.sender] = true;
    }

    function _selectWinner() internal view returns (address) {
        uint256 randomIndex = _generateRandomNumber() % participants.length;
        return participants[randomIndex];
    }

    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    participants.length,
                    blockhash(block.number - 1)
                )
            )
        );
    }

    function _resetLottery() internal {
        delete participants;
        winner = address(0);



    }
}
