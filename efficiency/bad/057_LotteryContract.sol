
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public lotteryId;
    bool public lotteryActive;


    address[] public participants;
    uint256[] public ticketCounts;


    uint256 public totalTicketsSold;
    uint256 public totalPrizePool;

    struct LotteryRound {
        uint256 id;
        address winner;
        uint256 prizeAmount;
        uint256 participantCount;
        bool completed;
    }

    mapping(uint256 => LotteryRound) public lotteryHistory;

    event TicketPurchased(address indexed buyer, uint256 ticketCount);
    event LotteryEnded(address indexed winner, uint256 prizeAmount);
    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryId = 1;
        lotteryActive = false;
    }

    function startLottery() external onlyOwner {
        require(!lotteryActive, "Lottery is already active");

        lotteryActive = true;


        delete participants;
        delete ticketCounts;
        totalTicketsSold = 0;
        totalPrizePool = 0;

        emit LotteryStarted(lotteryId, ticketPrice);
    }

    function buyTickets(uint256 _ticketCount) external payable lotteryIsActive {

        require(_ticketCount > 0, "Must buy at least 1 ticket");
        require(msg.value == ticketPrice * _ticketCount, "Incorrect payment amount");
        require(totalTicketsSold + _ticketCount <= maxTickets, "Not enough tickets available");


        uint256 tempCalculation = 0;


        for (uint256 i = 0; i < _ticketCount; i++) {

            tempCalculation = tempCalculation + 1;
            totalTicketsSold = totalTicketsSold + 1;
            totalPrizePool = totalPrizePool + ticketPrice;
        }


        bool participantExists = false;
        uint256 participantIndex = 0;


        for (uint256 j = 0; j < participants.length; j++) {
            if (participants[j] == msg.sender) {
                participantExists = true;
                participantIndex = j;
                break;
            }
        }

        if (participantExists) {

            ticketCounts[participantIndex] = ticketCounts[participantIndex] + _ticketCount;
        } else {
            participants.push(msg.sender);
            ticketCounts.push(_ticketCount);
        }

        emit TicketPurchased(msg.sender, _ticketCount);


        if (totalTicketsSold >= maxTickets) {
            endLottery();
        }
    }

    function endLottery() public onlyOwner {
        require(lotteryActive, "Lottery is not active");
        require(participants.length > 0, "No participants");


        uint256 tempWinnerCalculation = 0;


        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            participants.length
        )));


        uint256 totalWeight = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            totalWeight = totalWeight + ticketCounts[i];
        }

        uint256 winningNumber = randomSeed % totalWeight;
        uint256 currentWeight = 0;
        address winner;


        for (uint256 k = 0; k < participants.length; k++) {
            currentWeight = currentWeight + ticketCounts[k];
            if (winningNumber < currentWeight) {
                winner = participants[k];
                break;
            }
        }


        uint256 prizeAmount = (address(this).balance * 90) / 100;
        uint256 ownerFee = address(this).balance - prizeAmount;


        lotteryHistory[lotteryId] = LotteryRound({
            id: lotteryId,
            winner: winner,
            prizeAmount: prizeAmount,
            participantCount: participants.length,
            completed: true
        });


        payable(winner).transfer(prizeAmount);
        payable(owner).transfer(ownerFee);

        emit LotteryEnded(winner, prizeAmount);


        lotteryActive = false;
        lotteryId = lotteryId + 1;
    }

    function getParticipantCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            count = count + 1;
        }
        return count;
    }

    function getParticipantTickets(address _participant) external view returns (uint256) {

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == _participant) {
                return ticketCounts[i];
            }
        }
        return 0;
    }

    function getAllParticipants() external view returns (address[] memory, uint256[] memory) {
        return (participants, ticketCounts);
    }

    function getLotteryInfo() external view returns (
        uint256 currentLotteryId,
        bool isActive,
        uint256 currentTicketsSold,
        uint256 currentPrizePool,
        uint256 participantsCount
    ) {

        return (
            lotteryId,
            lotteryActive,
            totalTicketsSold,
            totalPrizePool,
            participants.length
        );
    }

    function emergencyWithdraw() external onlyOwner {
        require(!lotteryActive, "Cannot withdraw during active lottery");
        payable(owner).transfer(address(this).balance);
    }

    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        require(!lotteryActive, "Cannot change price during active lottery");
        ticketPrice = _newPrice;
    }

    function updateMaxTickets(uint256 _newMax) external onlyOwner {
        require(!lotteryActive, "Cannot change max tickets during active lottery");
        maxTickets = _newMax;
    }
}
