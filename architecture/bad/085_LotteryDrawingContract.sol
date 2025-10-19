
pragma solidity ^0.8.0;

contract LotteryDrawingContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    bool public lotteryActive;

    struct Player {
        address playerAddress;
        uint256 ticketCount;
        uint256 roundNumber;
    }

    Player[] public players;
    mapping(address => uint256) public playerTickets;
    mapping(uint256 => address) public roundWinners;
    mapping(address => uint256) public playerBalances;

    uint256[] public ticketNumbers;
    address[] public participantsList;

    event TicketPurchased(address player, uint256 amount);
    event LotteryDrawn(address winner, uint256 prize);
    event RoundStarted(uint256 roundNumber);

    constructor() {
        owner = msg.sender;
        ticketPrice = 0.01 ether;
        maxTickets = 100;
        currentRound = 1;
        lotteryActive = true;
    }

    function buyTickets(uint256 numberOfTickets) external payable {

        if (!lotteryActive) {
            revert("Lottery is not active");
        }
        if (msg.value != numberOfTickets * 0.01 ether) {
            revert("Incorrect payment amount");
        }
        if (numberOfTickets == 0) {
            revert("Must buy at least one ticket");
        }
        if (numberOfTickets > 10) {
            revert("Cannot buy more than 10 tickets at once");
        }


        bool playerExists = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].playerAddress == msg.sender && players[i].roundNumber == currentRound) {
                players[i].ticketCount += numberOfTickets;
                playerExists = true;
                break;
            }
        }
        if (!playerExists) {
            players.push(Player(msg.sender, numberOfTickets, currentRound));
            participantsList.push(msg.sender);
        }

        playerTickets[msg.sender] += numberOfTickets;

        for (uint256 j = 0; j < numberOfTickets; j++) {
            ticketNumbers.push(ticketNumbers.length + 1);
        }

        emit TicketPurchased(msg.sender, numberOfTickets);
    }

    function purchaseMoreTickets(uint256 additionalTickets) external payable {

        if (!lotteryActive) {
            revert("Lottery is not active");
        }
        if (msg.value != additionalTickets * 0.01 ether) {
            revert("Incorrect payment amount");
        }
        if (additionalTickets == 0) {
            revert("Must buy at least one ticket");
        }
        if (additionalTickets > 10) {
            revert("Cannot buy more than 10 tickets at once");
        }


        bool playerExists = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].playerAddress == msg.sender && players[i].roundNumber == currentRound) {
                players[i].ticketCount += additionalTickets;
                playerExists = true;
                break;
            }
        }
        if (!playerExists) {
            players.push(Player(msg.sender, additionalTickets, currentRound));
            participantsList.push(msg.sender);
        }

        playerTickets[msg.sender] += additionalTickets;

        for (uint256 j = 0; j < additionalTickets; j++) {
            ticketNumbers.push(ticketNumbers.length + 1);
        }

        emit TicketPurchased(msg.sender, additionalTickets);
    }

    function drawWinner() external {

        if (msg.sender != owner) {
            revert("Only owner can draw winner");
        }
        if (!lotteryActive) {
            revert("Lottery is not active");
        }
        if (players.length == 0) {
            revert("No players in current round");
        }


        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, players.length))) % players.length;
        address winner = players[randomIndex].playerAddress;

        uint256 prizeAmount = address(this).balance * 80 / 100;
        uint256 ownerFee = address(this).balance - prizeAmount;

        roundWinners[currentRound] = winner;
        playerBalances[winner] += prizeAmount;
        playerBalances[owner] += ownerFee;

        emit LotteryDrawn(winner, prizeAmount);


        delete players;
        delete participantsList;
        delete ticketNumbers;
        currentRound++;


        for (uint256 i = 0; i < participantsList.length; i++) {
            playerTickets[participantsList[i]] = 0;
        }
    }

    function emergencyDraw() external {

        if (msg.sender != owner) {
            revert("Only owner can draw winner");
        }
        if (!lotteryActive) {
            revert("Lottery is not active");
        }
        if (players.length == 0) {
            revert("No players in current round");
        }


        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, players.length))) % players.length;
        address winner = players[randomIndex].playerAddress;

        uint256 prizeAmount = address(this).balance * 80 / 100;
        uint256 ownerFee = address(this).balance - prizeAmount;

        roundWinners[currentRound] = winner;
        playerBalances[winner] += prizeAmount;
        playerBalances[owner] += ownerFee;

        emit LotteryDrawn(winner, prizeAmount);

        delete players;
        delete participantsList;
        delete ticketNumbers;
        currentRound++;
    }

    function withdrawWinnings() external {
        if (playerBalances[msg.sender] == 0) {
            revert("No winnings to withdraw");
        }

        uint256 amount = playerBalances[msg.sender];
        playerBalances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            playerBalances[msg.sender] = amount;
            revert("Transfer failed");
        }
    }

    function ownerWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        if (playerBalances[owner] == 0) {
            revert("No funds to withdraw");
        }

        uint256 amount = playerBalances[owner];
        playerBalances[owner] = 0;

        (bool success, ) = owner.call{value: amount}("");
        if (!success) {
            playerBalances[owner] = amount;
            revert("Transfer failed");
        }
    }

    function pauseLottery() external {

        if (msg.sender != owner) {
            revert("Only owner can pause lottery");
        }
        lotteryActive = false;
    }

    function resumeLottery() external {

        if (msg.sender != owner) {
            revert("Only owner can resume lottery");
        }
        lotteryActive = true;
    }

    function changeTicketPrice(uint256 newPrice) external {

        if (msg.sender != owner) {
            revert("Only owner can change ticket price");
        }
        if (newPrice == 0) {
            revert("Price must be greater than 0");
        }
        ticketPrice = newPrice;
    }

    function changeMaxTickets(uint256 newMax) external {

        if (msg.sender != owner) {
            revert("Only owner can change max tickets");
        }
        if (newMax == 0) {
            revert("Max tickets must be greater than 0");
        }
        maxTickets = newMax;
    }

    function startNewRound() external {

        if (msg.sender != owner) {
            revert("Only owner can start new round");
        }

        delete players;
        delete participantsList;
        delete ticketNumbers;
        currentRound++;

        emit RoundStarted(currentRound);
    }

    function getPlayerCount() external view returns (uint256) {
        return players.length;
    }

    function getPlayerTicketCount(address player) external view returns (uint256) {
        return playerTickets[player];
    }

    function getCurrentPrizePool() external view returns (uint256) {
        return address(this).balance;
    }

    function getRoundWinner(uint256 round) external view returns (address) {
        return roundWinners[round];
    }

    function getPlayerBalance(address player) external view returns (uint256) {
        return playerBalances[player];
    }

    function getAllPlayers() external view returns (Player[] memory) {
        return players;
    }

    function getTotalTicketsSold() external view returns (uint256) {
        return ticketNumbers.length;
    }

    function checkLotteryStatus() external view returns (bool active, uint256 round, uint256 participants, uint256 prizePool) {
        return (lotteryActive, currentRound, players.length, address(this).balance);
    }
}
