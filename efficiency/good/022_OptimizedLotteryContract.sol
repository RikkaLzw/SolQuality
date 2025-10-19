
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedLotteryContract is Ownable, ReentrancyGuard, Pausable {
    struct LotteryRound {
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 totalPrizePool;
        uint256 maxTickets;
        uint256 ticketsSold;
        address winner;
        bool isFinalized;
    }

    struct PlayerInfo {
        uint256[] ticketIds;
        uint256 totalSpent;
    }


    uint256 public currentRoundId;
    uint256 private constant HOUSE_FEE_PERCENTAGE = 5;
    uint256 private constant MAX_TICKETS_PER_PURCHASE = 100;


    mapping(uint256 => LotteryRound) public lotteryRounds;
    mapping(uint256 => mapping(address => PlayerInfo)) public playerInfo;
    mapping(uint256 => mapping(uint256 => address)) public ticketToPlayer;
    mapping(uint256 => address[]) private roundParticipants;


    event LotteryRoundStarted(uint256 indexed roundId, uint256 ticketPrice, uint256 maxTickets, uint256 endTime);
    event TicketsPurchased(uint256 indexed roundId, address indexed player, uint256 quantity, uint256[] ticketIds);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prizeAmount);
    event PrizeWithdrawn(uint256 indexed roundId, address indexed winner, uint256 amount);
    event HouseFeeWithdrawn(uint256 amount);

    constructor() {
        currentRoundId = 0;
    }

    function startNewLotteryRound(
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _durationInSeconds
    ) external onlyOwner whenNotPaused {
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_maxTickets > 0 && _maxTickets <= 10000, "Invalid max tickets");
        require(_durationInSeconds >= 300, "Duration must be at least 5 minutes");


        uint256 newRoundId = ++currentRoundId;
        LotteryRound storage newRound = lotteryRounds[newRoundId];

        newRound.startTime = block.timestamp;
        newRound.endTime = block.timestamp + _durationInSeconds;
        newRound.ticketPrice = _ticketPrice;
        newRound.maxTickets = _maxTickets;
        newRound.ticketsSold = 0;
        newRound.totalPrizePool = 0;
        newRound.winner = address(0);
        newRound.isFinalized = false;

        emit LotteryRoundStarted(newRoundId, _ticketPrice, _maxTickets, newRound.endTime);
    }

    function purchaseTickets(uint256 _roundId, uint256 _quantity)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(_quantity > 0 && _quantity <= MAX_TICKETS_PER_PURCHASE, "Invalid quantity");


        LotteryRound storage round = lotteryRounds[_roundId];
        require(block.timestamp >= round.startTime && block.timestamp < round.endTime, "Round not active");
        require(!round.isFinalized, "Round already finalized");

        uint256 cachedTicketsSold = round.ticketsSold;
        require(cachedTicketsSold + _quantity <= round.maxTickets, "Not enough tickets available");

        uint256 totalCost = round.ticketPrice * _quantity;
        require(msg.value == totalCost, "Incorrect payment amount");


        round.ticketsSold = cachedTicketsSold + _quantity;
        round.totalPrizePool += totalCost;


        PlayerInfo storage player = playerInfo[_roundId][msg.sender];


        if (player.ticketIds.length == 0) {
            roundParticipants[_roundId].push(msg.sender);
        }


        uint256[] memory newTicketIds = new uint256[](_quantity);
        for (uint256 i = 0; i < _quantity; i++) {
            uint256 ticketId = cachedTicketsSold + i + 1;
            newTicketIds[i] = ticketId;
            ticketToPlayer[_roundId][ticketId] = msg.sender;
            player.ticketIds.push(ticketId);
        }

        player.totalSpent += totalCost;

        emit TicketsPurchased(_roundId, msg.sender, _quantity, newTicketIds);
    }

    function selectWinner(uint256 _roundId) external onlyOwner nonReentrant {
        LotteryRound storage round = lotteryRounds[_roundId];
        require(block.timestamp >= round.endTime, "Round not ended yet");
        require(!round.isFinalized, "Round already finalized");
        require(round.ticketsSold > 0, "No tickets sold");


        uint256 winningTicket = _generateRandomNumber(_roundId, round.ticketsSold);
        address winner = ticketToPlayer[_roundId][winningTicket];

        round.winner = winner;
        round.isFinalized = true;


        uint256 prizeAmount = (round.totalPrizePool * (100 - HOUSE_FEE_PERCENTAGE)) / 100;

        emit WinnerSelected(_roundId, winner, prizeAmount);
    }

    function withdrawPrize(uint256 _roundId) external nonReentrant {
        LotteryRound storage round = lotteryRounds[_roundId];
        require(round.isFinalized, "Round not finalized");
        require(round.winner == msg.sender, "Not the winner");
        require(round.totalPrizePool > 0, "Prize already withdrawn");

        uint256 prizeAmount = (round.totalPrizePool * (100 - HOUSE_FEE_PERCENTAGE)) / 100;
        round.totalPrizePool = 0;

        (bool success, ) = payable(msg.sender).call{value: prizeAmount}("");
        require(success, "Prize transfer failed");

        emit PrizeWithdrawn(_roundId, msg.sender, prizeAmount);
    }

    function withdrawHouseFees() external onlyOwner nonReentrant {
        uint256 totalFees = 0;


        for (uint256 i = 1; i <= currentRoundId; i++) {
            LotteryRound storage round = lotteryRounds[i];
            if (round.isFinalized && round.totalPrizePool == 0) {

                continue;
            } else if (round.isFinalized) {
                uint256 houseFee = (round.totalPrizePool * HOUSE_FEE_PERCENTAGE) / 100;
                totalFees += houseFee;
            }
        }

        require(totalFees > 0, "No fees to withdraw");

        (bool success, ) = payable(owner()).call{value: totalFees}("");
        require(success, "Fee transfer failed");

        emit HouseFeeWithdrawn(totalFees);
    }

    function _generateRandomNumber(uint256 _roundId, uint256 _maxTickets) private view returns (uint256) {


        uint256 randomHash = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    _roundId,
                    msg.sender,
                    _maxTickets
                )
            )
        );
        return (randomHash % _maxTickets) + 1;
    }


    function getRoundInfo(uint256 _roundId) external view returns (LotteryRound memory) {
        return lotteryRounds[_roundId];
    }

    function getPlayerTickets(uint256 _roundId, address _player) external view returns (uint256[] memory) {
        return playerInfo[_roundId][_player].ticketIds;
    }

    function getRoundParticipants(uint256 _roundId) external view returns (address[] memory) {
        return roundParticipants[_roundId];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        require(paused(), "Contract must be paused");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }
}
