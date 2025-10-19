
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract OptimizedLotteryContract is ReentrancyGuard, Ownable, Pausable {

    struct LotteryRound {
        uint128 prizePool;
        uint64 endTime;
        uint32 ticketPrice;
        uint16 maxTickets;
        uint16 ticketsSold;
        bool isActive;
        bool prizeDistributed;
    }


    uint256 public currentRoundId;
    uint256 private nonce;


    mapping(uint256 => LotteryRound) public lotteryRounds;
    mapping(uint256 => address[]) public roundParticipants;
    mapping(uint256 => mapping(address => uint256)) public userTicketCount;
    mapping(address => uint256) public pendingWithdrawals;


    event RoundCreated(uint256 indexed roundId, uint256 ticketPrice, uint256 maxTickets, uint256 endTime);
    event TicketPurchased(uint256 indexed roundId, address indexed buyer, uint256 ticketCount);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prize);
    event PrizeWithdrawn(address indexed winner, uint256 amount);


    error RoundNotActive();
    error RoundEnded();
    error InvalidTicketCount();
    error InsufficientPayment();
    error MaxTicketsReached();
    error RoundNotEnded();
    error NoParticipants();
    error PrizeAlreadyDistributed();
    error NoWithdrawableAmount();

    constructor() {}


    function createLotteryRound(
        uint32 _ticketPrice,
        uint16 _maxTickets,
        uint64 _duration
    ) external onlyOwner {
        uint256 roundId = ++currentRoundId;

        lotteryRounds[roundId] = LotteryRound({
            prizePool: 0,
            endTime: uint64(block.timestamp + _duration),
            ticketPrice: _ticketPrice,
            maxTickets: _maxTickets,
            ticketsSold: 0,
            isActive: true,
            prizeDistributed: false
        });

        emit RoundCreated(roundId, _ticketPrice, _maxTickets, block.timestamp + _duration);
    }


    function buyTickets(uint256 _roundId, uint16 _ticketCount)
        external
        payable
        nonReentrant
        whenNotPaused
    {

        LotteryRound storage round = lotteryRounds[_roundId];

        if (!round.isActive) revert RoundNotActive();
        if (block.timestamp >= round.endTime) revert RoundEnded();
        if (_ticketCount == 0) revert InvalidTicketCount();

        uint256 totalCost = uint256(round.ticketPrice) * _ticketCount;
        if (msg.value < totalCost) revert InsufficientPayment();

        uint256 newTicketsSold = round.ticketsSold + _ticketCount;
        if (newTicketsSold > round.maxTickets) revert MaxTicketsReached();


        round.ticketsSold = uint16(newTicketsSold);
        round.prizePool += uint128(totalCost);
        userTicketCount[_roundId][msg.sender] += _ticketCount;


        address[] storage participants = roundParticipants[_roundId];
        for (uint256 i = 0; i < _ticketCount;) {
            participants.push(msg.sender);
            unchecked { ++i; }
        }


        if (msg.value > totalCost) {
            pendingWithdrawals[msg.sender] += msg.value - totalCost;
        }

        emit TicketPurchased(_roundId, msg.sender, _ticketCount);
    }


    function selectWinner(uint256 _roundId) external onlyOwner nonReentrant {
        LotteryRound storage round = lotteryRounds[_roundId];

        if (!round.isActive) revert RoundNotActive();
        if (block.timestamp < round.endTime) revert RoundNotEnded();
        if (round.prizeDistributed) revert PrizeAlreadyDistributed();

        address[] memory participants = roundParticipants[_roundId];
        if (participants.length == 0) revert NoParticipants();


        uint256 randomIndex = _generateRandomNumber(participants.length);
        address winner = participants[randomIndex];


        uint256 totalPrize = round.prizePool;
        uint256 winnerPrize = (totalPrize * 90) / 100;
        uint256 ownerFee = totalPrize - winnerPrize;


        round.isActive = false;
        round.prizeDistributed = true;


        pendingWithdrawals[winner] += winnerPrize;
        pendingWithdrawals[owner()] += ownerFee;

        emit WinnerSelected(_roundId, winner, winnerPrize);
    }


    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoWithdrawableAmount();

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit PrizeWithdrawn(msg.sender, amount);
    }


    function _generateRandomNumber(uint256 _max) private returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            nonce
        ))) % _max;
    }


    function getParticipantCount(uint256 _roundId) external view returns (uint256) {
        return roundParticipants[_roundId].length;
    }


    function getUserTicketCount(uint256 _roundId, address _user) external view returns (uint256) {
        return userTicketCount[_roundId][_user];
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw() external onlyOwner whenPaused {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }
}
