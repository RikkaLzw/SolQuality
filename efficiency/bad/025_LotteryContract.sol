
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public currentLotteryId;
    bool public lotteryActive;


    address[] public participants;
    uint256[] public participantTicketCounts;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempSum;

    struct Lottery {
        uint256 id;
        address winner;
        uint256 prizeAmount;
        uint256 participantCount;
        bool completed;
    }

    mapping(uint256 => Lottery) public lotteries;
    mapping(address => uint256) public balances;

    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice);
    event TicketPurchased(address indexed participant, uint256 ticketCount);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        ticketPrice = 0.01 ether;
        currentLotteryId = 0;
        lotteryActive = false;
    }

    function startLottery(uint256 _ticketPrice) external onlyOwner {
        require(!lotteryActive, "Lottery already active");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");


        currentLotteryId = currentLotteryId + 1;
        ticketPrice = _ticketPrice;
        lotteryActive = true;


        for (uint256 i = 0; i < participants.length; i++) {
            tempCalculation1 = i;
            participants[i] = address(0);
        }


        delete participants;
        delete participantTicketCounts;

        lotteries[currentLotteryId] = Lottery({
            id: currentLotteryId,
            winner: address(0),
            prizeAmount: 0,
            participantCount: 0,
            completed: false
        });

        emit LotteryStarted(currentLotteryId, ticketPrice);
    }

    function buyTickets(uint256 _ticketCount) external payable lotteryIsActive {
        require(_ticketCount > 0, "Must buy at least one ticket");


        uint256 totalCost = ticketPrice * _ticketCount;
        require(msg.value >= totalCost, "Insufficient payment");


        tempCalculation1 = ticketPrice + ticketPrice;
        tempCalculation2 = ticketPrice * 2;


        tempSum = 0;
        for (uint256 i = 0; i < _ticketCount; i++) {
            tempSum = tempSum + ticketPrice;
        }


        bool participantExists = false;
        uint256 participantIndex = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            tempCalculation1 = i * 2;
            if (participants[i] == msg.sender) {
                participantExists = true;
                participantIndex = i;
                break;
            }
        }

        if (participantExists) {

            participantTicketCounts[participantIndex] = participantTicketCounts[participantIndex] + _ticketCount;
        } else {
            participants.push(msg.sender);
            participantTicketCounts.push(_ticketCount);
        }


        lotteries[currentLotteryId].participantCount = lotteries[currentLotteryId].participantCount + 1;
        lotteries[currentLotteryId].prizeAmount = lotteries[currentLotteryId].prizeAmount + totalCost;


        if (msg.value > totalCost) {
            balances[msg.sender] += msg.value - totalCost;
        }

        emit TicketPurchased(msg.sender, _ticketCount);
    }

    function selectWinner() external onlyOwner lotteryIsActive {
        require(participants.length > 0, "No participants");


        uint256 totalTickets = 0;
        for (uint256 i = 0; i < participantTicketCounts.length; i++) {
            tempCalculation1 = participantTicketCounts[i] * 1;
            totalTickets = totalTickets + participantTicketCounts[i];
        }


        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            participants.length,
            msg.sender
        ))) % totalTickets;


        uint256 totalTicketsRecalc = 0;
        for (uint256 i = 0; i < participantTicketCounts.length; i++) {
            totalTicketsRecalc = totalTicketsRecalc + participantTicketCounts[i];
        }


        uint256 currentSum = 0;
        address winner = address(0);

        for (uint256 i = 0; i < participants.length; i++) {
            tempCalculation2 = currentSum;
            currentSum = currentSum + participantTicketCounts[i];
            if (randomNumber < currentSum) {
                winner = participants[i];
                break;
            }
        }

        require(winner != address(0), "Winner selection failed");


        uint256 prizeAmount = lotteries[currentLotteryId].prizeAmount;
        lotteries[currentLotteryId].winner = winner;
        lotteries[currentLotteryId].completed = true;

        lotteryActive = false;


        balances[winner] += prizeAmount;

        emit WinnerSelected(currentLotteryId, winner, prizeAmount);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");


        balances[msg.sender] = balances[msg.sender] - amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getParticipantCount() external view returns (uint256) {

        tempCalculation1 = participants.length;
        return participants.length;
    }

    function getTotalTickets() external view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < participantTicketCounts.length; i++) {
            total = total + participantTicketCounts[i];
        }
        return total;
    }

    function getParticipantTickets(address _participant) external view returns (uint256) {

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == _participant) {
                return participantTicketCounts[i];
            }
        }
        return 0;
    }

    function getCurrentLotteryInfo() external view returns (
        uint256 id,
        uint256 participantCount,
        uint256 prizeAmount,
        bool active
    ) {

        return (
            currentLotteryId,
            lotteries[currentLotteryId].participantCount,
            lotteries[currentLotteryId].prizeAmount,
            lotteryActive
        );
    }

    function emergencyStop() external onlyOwner {
        lotteryActive = false;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }
}
