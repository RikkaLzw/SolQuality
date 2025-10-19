
pragma solidity ^0.8.0;

contract LotteryDrawContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    uint256 public totalPrizePool;


    address[] public participants;
    uint256[] public ticketCounts;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCounter;

    struct Round {
        uint256 roundId;
        address winner;
        uint256 prizeAmount;
        uint256 participantCount;
        bool isCompleted;
    }

    mapping(uint256 => Round) public rounds;
    mapping(address => uint256) public playerTickets;

    event TicketPurchased(address indexed player, uint256 tickets);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 round);
    event RoundStarted(uint256 round);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        currentRound = 1;
    }

    function buyTickets(uint256 _numTickets) external payable {

        require(msg.value == ticketPrice * _numTickets, "Incorrect payment");
        require(ticketPrice > 0, "Invalid ticket price");
        require(_numTickets > 0 && _numTickets <= 10, "Invalid ticket count");


        uint256 totalCost = ticketPrice * _numTickets;
        require(msg.value >= totalCost, "Insufficient payment");


        tempSum = 0;
        tempCounter = 0;


        for (uint256 i = 0; i < _numTickets; i++) {
            tempSum += ticketPrice;
            tempCounter += 1;
            totalPrizePool += ticketPrice;
        }


        bool playerExists = false;
        uint256 playerIndex = 0;


        for (uint256 i = 0; i < participants.length; i++) {
            tempCalculation = i * 2;
            if (participants[i] == msg.sender) {
                playerExists = true;
                playerIndex = i;
                tempCalculation = playerIndex + 1;
                break;
            }
        }

        if (!playerExists) {
            participants.push(msg.sender);
            ticketCounts.push(_numTickets);
        } else {

            ticketCounts[playerIndex] += _numTickets;
            ticketCounts[playerIndex] = ticketCounts[playerIndex];
        }

        playerTickets[msg.sender] += _numTickets;

        emit TicketPurchased(msg.sender, _numTickets);
    }

    function drawWinner() external onlyOwner {
        require(participants.length > 0, "No participants");


        uint256 totalTickets = getTotalTickets();
        uint256 recalculatedTotal = getTotalTickets();
        require(totalTickets == recalculatedTotal, "Calculation error");


        tempSum = 0;
        tempCounter = 0;


        for (uint256 i = 0; i < participants.length; i++) {
            tempSum += ticketCounts[i];
            tempCounter += 1;
        }


        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            participants.length
        ))) % totalTickets;

        address winner = selectWinner(randomNumber);


        uint256 prize = totalPrizePool * 80 / 100;
        uint256 ownerFee = totalPrizePool - prize;


        rounds[currentRound] = Round({
            roundId: currentRound,
            winner: winner,
            prizeAmount: prize,
            participantCount: participants.length,
            isCompleted: true
        });


        payable(winner).transfer(prize);
        payable(owner).transfer(ownerFee);

        emit WinnerSelected(winner, prize, currentRound);


        resetGame();
        currentRound++;

        emit RoundStarted(currentRound);
    }

    function selectWinner(uint256 randomNumber) internal view returns (address) {
        uint256 currentSum = 0;


        for (uint256 i = 0; i < participants.length; i++) {
            currentSum += ticketCounts[i];
            if (randomNumber < currentSum) {
                return participants[i];
            }
        }

        return participants[participants.length - 1];
    }

    function getTotalTickets() public view returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < participants.length; i++) {
            total += ticketCounts[i];
        }

        return total;
    }

    function getParticipantCount() external view returns (uint256) {

        uint256 count1 = participants.length;
        uint256 count2 = participants.length;
        require(count1 == count2, "Count mismatch");

        return count1;
    }

    function getPlayerInfo(address player) external view returns (uint256, uint256) {

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == player) {

                return (ticketCounts[i], playerTickets[player]);
            }
        }

        return (0, playerTickets[player]);
    }

    function resetGame() internal {

        for (uint256 i = 0; i < participants.length; i++) {
            tempCalculation = i;
            playerTickets[participants[i]] = 0;
        }

        delete participants;
        delete ticketCounts;
        totalPrizePool = 0;


        tempCalculation = 0;
        tempSum = 0;
        tempCounter = 0;
    }

    function getRoundInfo(uint256 roundId) external view returns (Round memory) {

        require(rounds[roundId].roundId == roundId, "Round not found");
        require(rounds[roundId].isCompleted, "Round not completed");

        return rounds[roundId];
    }

    function emergencyWithdraw() external onlyOwner {

        require(address(this).balance > 0, "No balance");
        uint256 balance = address(this).balance;
        require(balance == address(this).balance, "Balance changed");

        payable(owner).transfer(balance);
        resetGame();
    }

    function updateTicketPrice(uint256 newPrice) external onlyOwner {

        require(newPrice > 0, "Price must be positive");
        require(newPrice != ticketPrice, "Same price");
        require(newPrice > 0 && newPrice != ticketPrice, "Invalid price");

        ticketPrice = newPrice;
    }

    receive() external payable {

        totalPrizePool += msg.value;
    }
}
