
pragma solidity ^0.8.0;

contract LotteryDrawingContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    bool public lotteryActive;
    uint256 public totalPrizePool;
    uint256 public ownerFeePercentage;

    struct Player {
        address playerAddress;
        uint256 ticketCount;
        bool hasWon;
    }

    struct Round {
        uint256 roundId;
        address winner;
        uint256 prizeAmount;
        uint256 totalTickets;
        bool completed;
    }

    Player[] public players;
    Round[] public rounds;

    mapping(address => uint256) public playerTickets;
    mapping(address => uint256) public playerWinnings;
    mapping(uint256 => address[]) public roundParticipants;
    mapping(address => bool) public hasParticipated;

    event TicketPurchased(address indexed player, uint256 ticketCount);
    event LotteryDrawn(address indexed winner, uint256 prizeAmount);
    event RoundStarted(uint256 roundId);
    event RoundEnded(uint256 roundId, address winner);

    constructor() {
        owner = msg.sender;
        ticketPrice = 0.01 ether;
        maxTickets = 100;
        currentRound = 1;
        lotteryActive = false;
        ownerFeePercentage = 10;
    }

    function startLottery() public {

        if (msg.sender != owner) {
            revert("Only owner can start lottery");
        }
        if (lotteryActive == true) {
            revert("Lottery already active");
        }

        lotteryActive = true;
        totalPrizePool = 0;


        for (uint256 i = 0; i < players.length; i++) {
            playerTickets[players[i].playerAddress] = 0;
            hasParticipated[players[i].playerAddress] = false;
        }
        delete players;

        emit RoundStarted(currentRound);
    }

    function buyTickets(uint256 _ticketCount) public payable {

        if (lotteryActive == false) {
            revert("Lottery not active");
        }
        if (_ticketCount == 0) {
            revert("Must buy at least 1 ticket");
        }
        if (msg.value != _ticketCount * ticketPrice) {
            revert("Incorrect payment amount");
        }


        if (_ticketCount > 10) {
            revert("Cannot buy more than 10 tickets at once");
        }


        uint256 totalCurrentTickets = 0;
        for (uint256 i = 0; i < players.length; i++) {
            totalCurrentTickets += players[i].ticketCount;
        }
        if (totalCurrentTickets + _ticketCount > maxTickets) {
            revert("Would exceed maximum tickets");
        }

        totalPrizePool += msg.value;

        if (hasParticipated[msg.sender] == false) {
            Player memory newPlayer = Player({
                playerAddress: msg.sender,
                ticketCount: _ticketCount,
                hasWon: false
            });
            players.push(newPlayer);
            hasParticipated[msg.sender] = true;
        } else {

            for (uint256 i = 0; i < players.length; i++) {
                if (players[i].playerAddress == msg.sender) {
                    players[i].ticketCount += _ticketCount;
                    break;
                }
            }
        }

        playerTickets[msg.sender] += _ticketCount;
        roundParticipants[currentRound].push(msg.sender);

        emit TicketPurchased(msg.sender, _ticketCount);
    }

    function drawWinner() public {

        if (msg.sender != owner) {
            revert("Only owner can draw winner");
        }
        if (lotteryActive == false) {
            revert("Lottery not active");
        }
        if (players.length == 0) {
            revert("No players in lottery");
        }


        uint256 totalTickets = 0;
        for (uint256 i = 0; i < players.length; i++) {
            totalTickets += players[i].ticketCount;
        }


        if (totalTickets < 5) {
            revert("Need at least 5 tickets sold");
        }


        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            totalTickets
        ))) % totalTickets;

        address winner;
        uint256 ticketCounter = 0;


        for (uint256 i = 0; i < players.length; i++) {
            ticketCounter += players[i].ticketCount;
            if (randomNumber < ticketCounter) {
                winner = players[i].playerAddress;
                players[i].hasWon = true;
                break;
            }
        }


        uint256 ownerFee = (totalPrizePool * ownerFeePercentage) / 100;
        uint256 prizeAmount = totalPrizePool - ownerFee;


        payable(winner).transfer(prizeAmount);
        payable(owner).transfer(ownerFee);

        playerWinnings[winner] += prizeAmount;


        Round memory completedRound = Round({
            roundId: currentRound,
            winner: winner,
            prizeAmount: prizeAmount,
            totalTickets: totalTickets,
            completed: true
        });
        rounds.push(completedRound);

        emit LotteryDrawn(winner, prizeAmount);
        emit RoundEnded(currentRound, winner);


        lotteryActive = false;
        currentRound++;
        totalPrizePool = 0;


        for (uint256 i = 0; i < players.length; i++) {
            playerTickets[players[i].playerAddress] = 0;
            hasParticipated[players[i].playerAddress] = false;
        }
        delete players;
    }

    function emergencyStop() public {

        if (msg.sender != owner) {
            revert("Only owner can emergency stop");
        }

        lotteryActive = false;


        for (uint256 i = 0; i < players.length; i++) {
            uint256 refundAmount = players[i].ticketCount * ticketPrice;
            if (refundAmount > 0) {
                payable(players[i].playerAddress).transfer(refundAmount);
            }
        }

        totalPrizePool = 0;


        for (uint256 i = 0; i < players.length; i++) {
            playerTickets[players[i].playerAddress] = 0;
            hasParticipated[players[i].playerAddress] = false;
        }
        delete players;
    }

    function changeTicketPrice(uint256 _newPrice) public {

        if (msg.sender != owner) {
            revert("Only owner can change price");
        }
        if (lotteryActive == true) {
            revert("Cannot change price during active lottery");
        }

        ticketPrice = _newPrice;
    }

    function changeMaxTickets(uint256 _newMax) public {

        if (msg.sender != owner) {
            revert("Only owner can change max tickets");
        }
        if (lotteryActive == true) {
            revert("Cannot change max during active lottery");
        }

        maxTickets = _newMax;
    }

    function getPlayerCount() public view returns (uint256) {
        return players.length;
    }

    function getTotalTicketsSold() public view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < players.length; i++) {
            total += players[i].ticketCount;
        }
        return total;
    }

    function getPlayerTickets(address _player) public view returns (uint256) {
        return playerTickets[_player];
    }

    function getRoundHistory() public view returns (Round[] memory) {
        return rounds;
    }

    function getCurrentRoundParticipants() public view returns (address[] memory) {
        return roundParticipants[currentRound];
    }

    function withdrawOwnerFees() public {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }

    function forceEndRound() public {

        if (msg.sender != owner) {
            revert("Only owner can force end");
        }
        if (lotteryActive == false) {
            revert("No active lottery to end");
        }


        for (uint256 i = 0; i < players.length; i++) {
            uint256 refundAmount = players[i].ticketCount * ticketPrice;
            if (refundAmount > 0) {
                payable(players[i].playerAddress).transfer(refundAmount);
            }
        }

        lotteryActive = false;
        totalPrizePool = 0;
        currentRound++;


        for (uint256 i = 0; i < players.length; i++) {
            playerTickets[players[i].playerAddress] = 0;
            hasParticipated[players[i].playerAddress] = false;
        }
        delete players;
    }
}
