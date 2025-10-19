
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

    modifier lotteryIsActive() {
        require(lotteryActive);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function startLottery(uint256 _ticketPrice, uint256 _maxTickets) external onlyOwner {
        require(!lotteryActive);
        require(_ticketPrice > 0);
        require(_maxTickets > 0);

        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        ticketsSold = 0;
        lotteryActive = true;
        lotteryId++;

        emit LotteryStarted(lotteryId, ticketPrice);
    }

    function buyTicket() external payable lotteryIsActive {
        require(msg.value == ticketPrice);
        require(ticketsSold < maxTickets);

        ticketHolders[ticketsSold] = msg.sender;
        playerTickets[msg.sender].push(ticketsSold);

        emit TicketPurchased(msg.sender, ticketsSold);

        ticketsSold++;

        if (ticketsSold == maxTickets) {
            endLottery();
        }
    }

    function endLottery() public onlyOwner {
        require(lotteryActive);
        require(ticketsSold > 0);

        uint256 winningTicket = generateRandomNumber() % ticketsSold;
        address winner = ticketHolders[winningTicket];
        uint256 prize = address(this).balance;

        lotteryActive = false;


        for (uint256 i = 0; i < ticketsSold; i++) {
            delete ticketHolders[i];
        }

        payable(winner).transfer(prize);

        emit LotteryEnded(winner, prize);
    }

    function emergencyWithdraw() external onlyOwner {
        require(!lotteryActive);

        uint256 balance = address(this).balance;

        payable(owner).transfer(balance);
    }

    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        require(!lotteryActive);
        require(_newPrice > 0);


        ticketPrice = _newPrice;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));


        owner = _newOwner;
    }

    function generateRandomNumber() private view returns (uint256) {
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

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function forceEndLottery() external onlyOwner {
        if (!lotteryActive) {
            revert Error1();
        }
        if (ticketsSold == 0) {
            revert Error2();
        }

        lotteryActive = false;


        for (uint256 i = 0; i < ticketsSold; i++) {
            address player = ticketHolders[i];
            payable(player).transfer(ticketPrice);
            delete ticketHolders[i];
        }

        ticketsSold = 0;
    }

    function cancelLottery() external onlyOwner {
        if (!lotteryActive) {
            revert Error3();
        }


        lotteryActive = false;
        ticketsSold = 0;
        ticketPrice = 0;
        maxTickets = 0;
    }
}
