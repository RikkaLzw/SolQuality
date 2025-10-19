
pragma solidity ^0.8.0;

contract LotteryContract {
    address public owner;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public ticketsSold;
    uint256 public lotteryId;
    bool public lotteryActive;

    mapping(uint256 => address) public ticketHolders;
    mapping(address => uint256[]) public playerTickets;

    error Error1();
    error Error2();
    error Error3();

    event TicketPurchased(address buyer, uint256 ticketNumber);
    event LotteryEnded(address winner, uint256 prize);
    event LotteryStarted(uint256 lotteryId, uint256 ticketPrice);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(uint256 _ticketPrice, uint256 _maxTickets) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        lotteryId = 1;
        lotteryActive = true;
    }

    function buyTicket() external payable {
        require(lotteryActive);
        require(msg.value == ticketPrice);
        require(ticketsSold < maxTickets);

        ticketHolders[ticketsSold] = msg.sender;
        playerTickets[msg.sender].push(ticketsSold);
        ticketsSold++;

        emit TicketPurchased(msg.sender, ticketsSold - 1);

        if (ticketsSold == maxTickets) {
            _endLottery();
        }
    }

    function _endLottery() internal {
        require(ticketsSold > 0);

        uint256 winningTicket = _generateRandomNumber() % ticketsSold;
        address winner = ticketHolders[winningTicket];
        uint256 prize = address(this).balance;

        lotteryActive = false;

        payable(winner).transfer(prize);

        emit LotteryEnded(winner, prize);
    }

    function startNewLottery(uint256 _ticketPrice, uint256 _maxTickets) external onlyOwner {
        require(!lotteryActive);

        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        ticketsSold = 0;
        lotteryId++;
        lotteryActive = true;

        for (uint256 i = 0; i < maxTickets; i++) {
            delete ticketHolders[i];
        }

        emit LotteryStarted(lotteryId, ticketPrice);
    }

    function forceEndLottery() external onlyOwner {
        require(lotteryActive);
        require(ticketsSold > 0);

        _endLottery();
    }

    function withdrawEmergency() external onlyOwner {
        require(!lotteryActive);

        payable(owner).transfer(address(this).balance);
    }

    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender,
            ticketsSold
        )));
    }

    function getPlayerTickets(address player) external view returns (uint256[] memory) {
        return playerTickets[player];
    }

    function getCurrentPrizePool() external view returns (uint256) {
        return address(this).balance;
    }

    function getRemainingTickets() external view returns (uint256) {
        if (!lotteryActive) {
            return 0;
        }
        return maxTickets - ticketsSold;
    }

    function changeTicketPrice(uint256 _newPrice) external onlyOwner {
        require(lotteryActive);
        require(ticketsSold == 0);

        ticketPrice = _newPrice;
    }

    function pauseLottery() external onlyOwner {
        require(lotteryActive);

        lotteryActive = false;
    }

    function resumeLottery() external onlyOwner {
        require(!lotteryActive);
        require(ticketsSold < maxTickets);

        lotteryActive = true;
    }
}
