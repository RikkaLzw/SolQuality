
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LotteryContract is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 public constant MIN_TICKET_PRICE = 0.001 ether;
    uint256 public constant MAX_TICKET_PRICE = 10 ether;
    uint256 public constant MIN_PARTICIPANTS = 2;
    uint256 public constant MAX_PARTICIPANTS = 1000;
    uint256 public constant HOUSE_FEE_PERCENTAGE = 5;
    uint256 public constant WINNER_PERCENTAGE = 95;

    enum LotteryState { INACTIVE, ACTIVE, DRAWING, COMPLETED }

    struct Lottery {
        uint256 id;
        uint256 ticketPrice;
        uint256 maxParticipants;
        uint256 totalPool;
        uint256 participantCount;
        address[] participants;
        address winner;
        LotteryState state;
        uint256 startTime;
        uint256 endTime;
    }


    uint256 private _lotteryCounter;
    uint256 public currentLotteryId;
    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => mapping(address => uint256)) public participantTickets;
    mapping(address => uint256) public pendingWithdrawals;


    event LotteryCreated(uint256 indexed lotteryId, uint256 ticketPrice, uint256 maxParticipants);
    event TicketPurchased(uint256 indexed lotteryId, address indexed participant, uint256 ticketCount);
    event LotteryDrawn(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event LotteryCompleted(uint256 indexed lotteryId);
    event WithdrawalMade(address indexed recipient, uint256 amount);


    modifier validLotteryId(uint256 _lotteryId) {
        require(_lotteryId > 0 && _lotteryId <= _lotteryCounter, "Invalid lottery ID");
        _;
    }

    modifier lotteryInState(uint256 _lotteryId, LotteryState _state) {
        require(lotteries[_lotteryId].state == _state, "Lottery not in required state");
        _;
    }

    modifier onlyActiveLottery() {
        require(currentLotteryId > 0, "No active lottery");
        require(lotteries[currentLotteryId].state == LotteryState.ACTIVE, "Lottery not active");
        _;
    }

    modifier validTicketPrice(uint256 _price) {
        require(_price >= MIN_TICKET_PRICE && _price <= MAX_TICKET_PRICE, "Invalid ticket price");
        _;
    }

    modifier validParticipantCount(uint256 _count) {
        require(_count >= MIN_PARTICIPANTS && _count <= MAX_PARTICIPANTS, "Invalid participant count");
        _;
    }

    constructor() {}


    function createLottery(
        uint256 _ticketPrice,
        uint256 _maxParticipants,
        uint256 _duration
    )
        external
        onlyOwner
        validTicketPrice(_ticketPrice)
        validParticipantCount(_maxParticipants)
    {
        require(currentLotteryId == 0 || lotteries[currentLotteryId].state != LotteryState.ACTIVE,
                "Active lottery exists");
        require(_duration > 0, "Duration must be positive");

        _lotteryCounter = _lotteryCounter.add(1);
        currentLotteryId = _lotteryCounter;

        Lottery storage newLottery = lotteries[currentLotteryId];
        newLottery.id = currentLotteryId;
        newLottery.ticketPrice = _ticketPrice;
        newLottery.maxParticipants = _maxParticipants;
        newLottery.state = LotteryState.ACTIVE;
        newLottery.startTime = block.timestamp;
        newLottery.endTime = block.timestamp.add(_duration);

        emit LotteryCreated(currentLotteryId, _ticketPrice, _maxParticipants);
    }


    function buyTickets(uint256 _ticketCount)
        external
        payable
        nonReentrant
        onlyActiveLottery
    {
        require(_ticketCount > 0, "Must buy at least one ticket");
        require(block.timestamp <= lotteries[currentLotteryId].endTime, "Lottery has ended");

        Lottery storage lottery = lotteries[currentLotteryId];
        uint256 totalCost = lottery.ticketPrice.mul(_ticketCount);
        require(msg.value == totalCost, "Incorrect payment amount");
        require(lottery.participantCount.add(_ticketCount) <= lottery.maxParticipants,
                "Exceeds max participants");


        if (participantTickets[currentLotteryId][msg.sender] == 0) {
            lottery.participants.push(msg.sender);
        }

        participantTickets[currentLotteryId][msg.sender] =
            participantTickets[currentLotteryId][msg.sender].add(_ticketCount);
        lottery.participantCount = lottery.participantCount.add(_ticketCount);
        lottery.totalPool = lottery.totalPool.add(totalCost);

        emit TicketPurchased(currentLotteryId, msg.sender, _ticketCount);


        if (lottery.participantCount == lottery.maxParticipants) {
            _drawWinner(currentLotteryId);
        }
    }


    function drawLottery(uint256 _lotteryId)
        external
        onlyOwner
        validLotteryId(_lotteryId)
        lotteryInState(_lotteryId, LotteryState.ACTIVE)
    {
        require(block.timestamp >= lotteries[_lotteryId].endTime ||
                lotteries[_lotteryId].participantCount >= MIN_PARTICIPANTS,
                "Cannot draw yet");

        _drawWinner(_lotteryId);
    }


    function _drawWinner(uint256 _lotteryId) internal {
        Lottery storage lottery = lotteries[_lotteryId];
        require(lottery.participants.length >= MIN_PARTICIPANTS, "Not enough participants");

        lottery.state = LotteryState.DRAWING;


        uint256 randomIndex = _generateRandomNumber() % lottery.participants.length;
        address winner = lottery.participants[randomIndex];

        lottery.winner = winner;
        lottery.state = LotteryState.COMPLETED;


        uint256 houseFee = lottery.totalPool.mul(HOUSE_FEE_PERCENTAGE).div(100);
        uint256 winnerPrize = lottery.totalPool.mul(WINNER_PERCENTAGE).div(100);


        pendingWithdrawals[winner] = pendingWithdrawals[winner].add(winnerPrize);
        pendingWithdrawals[owner()] = pendingWithdrawals[owner()].add(houseFee);

        emit LotteryDrawn(_lotteryId, winner, winnerPrize);
        emit LotteryCompleted(_lotteryId);


        if (_lotteryId == currentLotteryId) {
            currentLotteryId = 0;
        }
    }


    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawals");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit WithdrawalMade(msg.sender, amount);
    }


    function _generateRandomNumber() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            block.coinbase,
            blockhash(block.number - 1),
            msg.sender
        )));
    }


    function getLotteryDetails(uint256 _lotteryId)
        external
        view
        validLotteryId(_lotteryId)
        returns (
            uint256 id,
            uint256 ticketPrice,
            uint256 maxParticipants,
            uint256 totalPool,
            uint256 participantCount,
            address winner,
            LotteryState state,
            uint256 startTime,
            uint256 endTime
        )
    {
        Lottery storage lottery = lotteries[_lotteryId];
        return (
            lottery.id,
            lottery.ticketPrice,
            lottery.maxParticipants,
            lottery.totalPool,
            lottery.participantCount,
            lottery.winner,
            lottery.state,
            lottery.startTime,
            lottery.endTime
        );
    }


    function getParticipantTickets(uint256 _lotteryId, address _participant)
        external
        view
        validLotteryId(_lotteryId)
        returns (uint256)
    {
        return participantTickets[_lotteryId][_participant];
    }


    function getParticipants(uint256 _lotteryId)
        external
        view
        validLotteryId(_lotteryId)
        returns (address[] memory)
    {
        return lotteries[_lotteryId].participants;
    }


    function emergencyCancel() external onlyOwner {
        require(currentLotteryId > 0, "No active lottery");
        Lottery storage lottery = lotteries[currentLotteryId];
        require(lottery.state == LotteryState.ACTIVE, "Lottery not active");

        lottery.state = LotteryState.INACTIVE;


        for (uint256 i = 0; i < lottery.participants.length; i++) {
            address participant = lottery.participants[i];
            uint256 ticketCount = participantTickets[currentLotteryId][participant];
            uint256 refundAmount = ticketCount.mul(lottery.ticketPrice);

            pendingWithdrawals[participant] = pendingWithdrawals[participant].add(refundAmount);
            participantTickets[currentLotteryId][participant] = 0;
        }

        currentLotteryId = 0;
    }


    function hasLotteryEnded(uint256 _lotteryId)
        external
        view
        validLotteryId(_lotteryId)
        returns (bool)
    {
        return block.timestamp >= lotteries[_lotteryId].endTime;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
