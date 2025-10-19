
pragma solidity ^0.8.0;

contract LotteryDrawingContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public currentRound;
    bool public lotteryActive;
    uint256 public totalPrizePool;
    uint256 public ticketsSold;

    struct Player {
        address playerAddress;
        uint256 ticketCount;
        uint256 roundNumber;
    }

    Player[] public players;
    mapping(address => uint256) public playerTicketCounts;
    mapping(uint256 => address) public roundWinners;
    mapping(uint256 => uint256) public roundPrizePools;
    address[] public allParticipants;

    event TicketPurchased(address indexed player, uint256 ticketCount, uint256 round);
    event LotteryDrawn(address indexed winner, uint256 prizeAmount, uint256 round);
    event LotteryStarted(uint256 round, uint256 ticketPrice, uint256 maxTickets);
    event LotteryEnded(uint256 round);

    constructor() {
        owner = msg.sender;
        ticketPrice = 0.01 ether;
        maxTickets = 100;
        currentRound = 1;
        lotteryActive = false;
        totalPrizePool = 0;
        ticketsSold = 0;
    }

    function startLottery() external {

        if (msg.sender != owner) {
            revert("Only owner can start lottery");
        }

        if (lotteryActive) {
            revert("Lottery already active");
        }

        lotteryActive = true;
        ticketsSold = 0;
        totalPrizePool = 0;


        delete players;
        delete allParticipants;

        emit LotteryStarted(currentRound, ticketPrice, maxTickets);
    }

    function buyTickets(uint256 _ticketCount) external payable {

        if (!lotteryActive) {
            revert("Lottery not active");
        }

        if (_ticketCount == 0) {
            revert("Must buy at least 1 ticket");
        }

        if (ticketsSold + _ticketCount > maxTickets) {
            revert("Not enough tickets available");
        }


        if (msg.value != _ticketCount * 0.01 ether) {
            revert("Incorrect payment amount");
        }


        bool playerExists = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].playerAddress == msg.sender && players[i].roundNumber == currentRound) {
                players[i].ticketCount += _ticketCount;
                playerExists = true;
                break;
            }
        }

        if (!playerExists) {
            players.push(Player({
                playerAddress: msg.sender,
                ticketCount: _ticketCount,
                roundNumber: currentRound
            }));
            allParticipants.push(msg.sender);
        }

        playerTicketCounts[msg.sender] += _ticketCount;
        ticketsSold += _ticketCount;
        totalPrizePool += msg.value;

        emit TicketPurchased(msg.sender, _ticketCount, currentRound);


        if (ticketsSold >= maxTickets) {
            drawWinner();
        }
    }

    function drawWinner() public {

        if (msg.sender != owner) {
            revert("Only owner can draw winner");
        }


        if (!lotteryActive) {
            revert("Lottery not active");
        }

        if (players.length == 0) {
            revert("No players in lottery");
        }


        uint256 totalTickets = 0;
        for (uint256 i = 0; i < players.length; i++) {
            totalTickets += players[i].ticketCount;
        }


        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            totalTickets
        ))) % totalTickets;

        address winner;
        uint256 currentCount = 0;


        for (uint256 i = 0; i < players.length; i++) {
            currentCount += players[i].ticketCount;
            if (randomNumber < currentCount) {
                winner = players[i].playerAddress;
                break;
            }
        }


        uint256 prizeAmount = (totalPrizePool * 90) / 100;
        uint256 ownerFee = totalPrizePool - prizeAmount;

        roundWinners[currentRound] = winner;
        roundPrizePools[currentRound] = prizeAmount;


        payable(winner).transfer(prizeAmount);
        payable(owner).transfer(ownerFee);

        emit LotteryDrawn(winner, prizeAmount, currentRound);


        lotteryActive = false;
        currentRound++;


        ticketsSold = 0;
        totalPrizePool = 0;


        for (uint256 i = 0; i < allParticipants.length; i++) {
            playerTicketCounts[allParticipants[i]] = 0;
        }

        emit LotteryEnded(currentRound - 1);
    }

    function emergencyEndLottery() external {

        if (msg.sender != owner) {
            revert("Only owner can end lottery");
        }

        if (!lotteryActive) {
            revert("Lottery not active");
        }


        for (uint256 i = 0; i < players.length; i++) {
            address playerAddr = players[i].playerAddress;
            uint256 ticketCount = players[i].ticketCount;
            uint256 refundAmount = ticketCount * 0.01 ether;

            payable(playerAddr).transfer(refundAmount);
        }


        lotteryActive = false;
        ticketsSold = 0;
        totalPrizePool = 0;


        delete players;
        delete allParticipants;

        for (uint256 i = 0; i < allParticipants.length; i++) {
            playerTicketCounts[allParticipants[i]] = 0;
        }

        emit LotteryEnded(currentRound);
    }

    function getPlayerTickets(address _player) external view returns (uint256) {
        return playerTicketCounts[_player];
    }

    function getCurrentRoundInfo() external view returns (
        uint256 round,
        bool active,
        uint256 sold,
        uint256 max,
        uint256 price,
        uint256 prizePool
    ) {
        return (currentRound, lotteryActive, ticketsSold, maxTickets, ticketPrice, totalPrizePool);
    }

    function getPlayersCount() external view returns (uint256) {
        return players.length;
    }

    function getPlayer(uint256 _index) external view returns (address, uint256, uint256) {

        Player memory player = players[_index];
        return (player.playerAddress, player.ticketCount, player.roundNumber);
    }

    function getRoundWinner(uint256 _round) external view returns (address) {
        return roundWinners[_round];
    }

    function getRoundPrizePool(uint256 _round) external view returns (uint256) {
        return roundPrizePools[_round];
    }

    function changeTicketPrice(uint256 _newPrice) external {

        if (msg.sender != owner) {
            revert("Only owner can change price");
        }

        if (lotteryActive) {
            revert("Cannot change price during active lottery");
        }

        ticketPrice = _newPrice;
    }

    function changeMaxTickets(uint256 _newMax) external {

        if (msg.sender != owner) {
            revert("Only owner can change max tickets");
        }

        if (lotteryActive) {
            revert("Cannot change max tickets during active lottery");
        }


        if (_newMax < 10) {
            revert("Max tickets must be at least 10");
        }

        maxTickets = _newMax;
    }

    function withdrawEmergency() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        if (lotteryActive) {
            revert("Cannot withdraw during active lottery");
        }

        payable(owner).transfer(address(this).balance);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function calculatePrize(uint256 _totalPool) public pure returns (uint256, uint256) {

        uint256 winnerPrize = (_totalPool * 90) / 100;
        uint256 ownerFee = _totalPool - winnerPrize;
        return (winnerPrize, ownerFee);
    }


    function isValidTicketCount(uint256 _count) public view returns (bool) {

        return _count > 0 && _count <= 50 && ticketsSold + _count <= maxTickets;
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
