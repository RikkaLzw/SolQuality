
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OptimizedLotteryContract is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;


    uint256 public currentLotteryId;
    uint256 public ticketPrice;
    uint256 public maxTicketsPerLottery;
    uint256 public ownerFeePercent;


    struct Lottery {
        uint128 totalTickets;
        uint128 prizePool;
        uint64 startTime;
        uint64 endTime;
        uint32 winnerTicketNumber;
        address winner;
        bool isFinalized;
        bool exists;
    }


    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => mapping(address => uint256)) public userTicketCounts;
    mapping(uint256 => mapping(uint256 => address)) public ticketOwners;


    event LotteryCreated(uint256 indexed lotteryId, uint256 ticketPrice, uint256 maxTickets, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketNumber, uint256 amount);
    event WinnerDrawn(uint256 indexed lotteryId, address indexed winner, uint256 ticketNumber, uint256 prize);
    event PrizeWithdrawn(uint256 indexed lotteryId, address indexed winner, uint256 amount);


    error LotteryNotExists();
    error LotteryEnded();
    error LotteryNotEnded();
    error InvalidTicketPrice();
    error MaxTicketsReached();
    error AlreadyFinalized();
    error NotWinner();
    error PrizeAlreadyWithdrawn();
    error InsufficientPayment();
    error InvalidFeePercent();

    modifier lotteryExists(uint256 _lotteryId) {
        if (!lotteries[_lotteryId].exists) revert LotteryNotExists();
        _;
    }

    modifier lotteryActive(uint256 _lotteryId) {
        Lottery storage lottery = lotteries[_lotteryId];
        if (block.timestamp >= lottery.endTime) revert LotteryEnded();
        _;
    }

    constructor(
        uint256 _ticketPrice,
        uint256 _maxTicketsPerLottery,
        uint256 _ownerFeePercent
    ) {
        if (_ticketPrice == 0) revert InvalidTicketPrice();
        if (_ownerFeePercent > 5000) revert InvalidFeePercent();

        ticketPrice = _ticketPrice;
        maxTicketsPerLottery = _maxTicketsPerLottery;
        ownerFeePercent = _ownerFeePercent;
    }

    function createLottery(uint256 _duration) external onlyOwner {
        uint256 lotteryId = ++currentLotteryId;
        uint64 endTime = uint64(block.timestamp + _duration);


        lotteries[lotteryId] = Lottery({
            totalTickets: 0,
            prizePool: 0,
            startTime: uint64(block.timestamp),
            endTime: endTime,
            winnerTicketNumber: 0,
            winner: address(0),
            isFinalized: false,
            exists: true
        });

        emit LotteryCreated(lotteryId, ticketPrice, maxTicketsPerLottery, endTime);
    }

    function buyTickets(uint256 _lotteryId, uint256 _ticketCount)
        external
        payable
        nonReentrant
        lotteryExists(_lotteryId)
        lotteryActive(_lotteryId)
    {
        if (msg.value != ticketPrice * _ticketCount) revert InsufficientPayment();


        Lottery storage lottery = lotteries[_lotteryId];
        uint256 currentTotal = lottery.totalTickets;
        uint256 newTotal = currentTotal + _ticketCount;

        if (newTotal > maxTicketsPerLottery) revert MaxTicketsReached();


        for (uint256 i = 0; i < _ticketCount;) {
            uint256 ticketNumber = currentTotal + i + 1;
            ticketOwners[_lotteryId][ticketNumber] = msg.sender;

            unchecked { ++i; }
        }


        lottery.totalTickets = uint128(newTotal);
        lottery.prizePool += uint128(msg.value);
        userTicketCounts[_lotteryId][msg.sender] += _ticketCount;

        emit TicketPurchased(_lotteryId, msg.sender, newTotal, msg.value);
    }

    function drawWinner(uint256 _lotteryId)
        external
        onlyOwner
        lotteryExists(_lotteryId)
    {
        Lottery storage lottery = lotteries[_lotteryId];

        if (block.timestamp < lottery.endTime) revert LotteryNotEnded();
        if (lottery.isFinalized) revert AlreadyFinalized();
        if (lottery.totalTickets == 0) {
            lottery.isFinalized = true;
            return;
        }


        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            block.number,
            lottery.totalTickets,
            lottery.prizePool
        )));

        uint256 winningTicket = (randomSeed % lottery.totalTickets) + 1;
        address winner = ticketOwners[_lotteryId][winningTicket];

        lottery.winnerTicketNumber = uint32(winningTicket);
        lottery.winner = winner;
        lottery.isFinalized = true;

        emit WinnerDrawn(_lotteryId, winner, winningTicket, lottery.prizePool);
    }

    function withdrawPrize(uint256 _lotteryId)
        external
        nonReentrant
        lotteryExists(_lotteryId)
    {
        Lottery storage lottery = lotteries[_lotteryId];

        if (!lottery.isFinalized) revert LotteryNotEnded();
        if (msg.sender != lottery.winner) revert NotWinner();
        if (lottery.prizePool == 0) revert PrizeAlreadyWithdrawn();


        uint256 totalPrize = lottery.prizePool;
        uint256 ownerFee = (totalPrize * ownerFeePercent) / 10000;
        uint256 winnerPrize = totalPrize - ownerFee;


        lottery.prizePool = 0;


        if (winnerPrize > 0) {
            (bool success1, ) = payable(msg.sender).call{value: winnerPrize}("");
            require(success1, "Winner transfer failed");
        }

        if (ownerFee > 0) {
            (bool success2, ) = payable(owner()).call{value: ownerFee}("");
            require(success2, "Owner fee transfer failed");
        }

        emit PrizeWithdrawn(_lotteryId, msg.sender, winnerPrize);
    }


    function getLotteryInfo(uint256 _lotteryId)
        external
        view
        lotteryExists(_lotteryId)
        returns (
            uint256 totalTickets,
            uint256 prizePool,
            uint256 startTime,
            uint256 endTime,
            address winner,
            bool isFinalized,
            bool isActive
        )
    {
        Lottery memory lottery = lotteries[_lotteryId];

        return (
            lottery.totalTickets,
            lottery.prizePool,
            lottery.startTime,
            lottery.endTime,
            lottery.winner,
            lottery.isFinalized,
            block.timestamp < lottery.endTime
        );
    }

    function getUserTickets(uint256 _lotteryId, address _user)
        external
        view
        returns (uint256)
    {
        return userTicketCounts[_lotteryId][_user];
    }


    function updateTicketPrice(uint256 _newPrice) external onlyOwner {
        if (_newPrice == 0) revert InvalidTicketPrice();
        ticketPrice = _newPrice;
    }

    function updateOwnerFeePercent(uint256 _newFeePercent) external onlyOwner {
        if (_newFeePercent > 5000) revert InvalidFeePercent();
        ownerFeePercent = _newFeePercent;
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "Emergency withdraw failed");
        }
    }
}
