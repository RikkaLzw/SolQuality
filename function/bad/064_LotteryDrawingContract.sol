
pragma solidity ^0.8.0;

contract LotteryDrawingContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public drawTime;
    bool public isActive;
    uint256 public currentRound;

    struct Player {
        address playerAddress;
        uint256 ticketCount;
        uint256 totalSpent;
        bool isVIP;
        uint256 joinTime;
    }

    mapping(uint256 => Player[]) public roundPlayers;
    mapping(address => uint256) public playerBalances;
    mapping(uint256 => address) public roundWinners;
    mapping(address => bool) public blacklist;

    event TicketPurchased(address indexed player, uint256 amount);
    event DrawCompleted(uint256 indexed round, address winner, uint256 prize);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        ticketPrice = 0.01 ether;
        maxTickets = 1000;
        drawTime = block.timestamp + 7 days;
        isActive = true;
        currentRound = 1;
    }




    function purchaseTicketsAndUpdatePlayerStatus(
        uint256 ticketAmount,
        bool setVIPStatus,
        uint256 customPrice,
        bool updateDrawTime,
        uint256 newDrawTime,
        address referrer
    ) public payable {
        require(!blacklist[msg.sender], "Player blacklisted");
        require(isActive, "Lottery not active");
        require(ticketAmount > 0, "Invalid ticket amount");

        uint256 finalPrice = customPrice > 0 ? customPrice : ticketPrice;
        require(msg.value >= finalPrice * ticketAmount, "Insufficient payment");


        Player memory newPlayer = Player({
            playerAddress: msg.sender,
            ticketCount: ticketAmount,
            totalSpent: msg.value,
            isVIP: setVIPStatus,
            joinTime: block.timestamp
        });

        roundPlayers[currentRound].push(newPlayer);
        playerBalances[msg.sender] += ticketAmount;


        if (setVIPStatus && msg.value >= 1 ether) {

            playerBalances[msg.sender] += ticketAmount / 10;
        }


        if (updateDrawTime && msg.sender == owner) {
            drawTime = newDrawTime;
        }


        if (referrer != address(0) && referrer != msg.sender) {
            playerBalances[referrer] += ticketAmount / 20;
        }

        emit TicketPurchased(msg.sender, ticketAmount);
    }


    function calculateRandomNumber() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            roundPlayers[currentRound].length
        )));
    }


    function conductDrawAndDistributePrizes() public onlyOwner {
        require(block.timestamp >= drawTime, "Draw time not reached");
        require(roundPlayers[currentRound].length > 0, "No players");

        uint256 totalPlayers = roundPlayers[currentRound].length;
        uint256 randomIndex = calculateRandomNumber() % totalPlayers;
        address winner = roundPlayers[currentRound][randomIndex].playerAddress;


        if (totalPlayers > 10) {
            if (totalPlayers > 50) {
                if (totalPlayers > 100) {
                    if (totalPlayers > 500) {

                        uint256 mainPrize = address(this).balance * 60 / 100;
                        uint256 secondPrize = address(this).balance * 20 / 100;
                        uint256 thirdPrize = address(this).balance * 10 / 100;

                        payable(winner).transfer(mainPrize);


                        if (totalPlayers > randomIndex + 1) {
                            address secondWinner = roundPlayers[currentRound][(randomIndex + 1) % totalPlayers].playerAddress;
                            if (secondWinner != winner) {
                                payable(secondWinner).transfer(secondPrize);

                                if (totalPlayers > randomIndex + 2) {
                                    address thirdWinner = roundPlayers[currentRound][(randomIndex + 2) % totalPlayers].playerAddress;
                                    if (thirdWinner != winner && thirdWinner != secondWinner) {
                                        payable(thirdWinner).transfer(thirdPrize);
                                    }
                                }
                            }
                        }
                    } else {

                        uint256 prize = address(this).balance * 70 / 100;
                        payable(winner).transfer(prize);
                    }
                } else {

                    uint256 prize = address(this).balance * 80 / 100;
                    payable(winner).transfer(prize);
                }
            } else {

                uint256 prize = address(this).balance * 85 / 100;
                payable(winner).transfer(prize);
            }
        } else {

            uint256 prize = address(this).balance * 90 / 100;
            payable(winner).transfer(prize);
        }

        roundWinners[currentRound] = winner;
        emit DrawCompleted(currentRound, winner, address(this).balance);


        currentRound++;
        drawTime = block.timestamp + 7 days;
    }

    function setLotteryParameters(
        uint256 _ticketPrice,
        uint256 _maxTickets,
        bool _isActive
    ) public onlyOwner {
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        isActive = _isActive;
    }

    function addToBlacklist(address player) public onlyOwner {
        blacklist[player] = true;
    }

    function removeFromBlacklist(address player) public onlyOwner {
        blacklist[player] = false;
    }

    function getRoundPlayersCount(uint256 round) public view returns (uint256) {
        return roundPlayers[round].length;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
