
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {

    mapping(address => mapping(address => uint256)) public balances;


    mapping(bytes32 => Order) public orders;


    uint32 public orderCounter;


    mapping(bytes32 => bool) public orderFilled;


    uint16 public feeRate = 30;


    address public feeRecipient;


    address public owner;

    struct Order {
        address maker;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint64 expires;
        uint32 nonce;
        bytes32 orderHash;
    }

    event Deposit(address indexed token, address indexed user, uint256 amount, uint256 balance);
    event Withdraw(address indexed token, address indexed user, uint256 amount, uint256 balance);
    event OrderPlaced(bytes32 indexed orderHash, address indexed maker, address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive);
    event Trade(bytes32 indexed orderHash, address indexed maker, address indexed taker, address tokenGet, uint256 amountGet, address tokenGive, uint256 amountGive);
    event OrderCancelled(bytes32 indexed orderHash, address indexed maker);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _feeRecipient) {
        owner = msg.sender;
        feeRecipient = _feeRecipient;
    }

    function deposit() external payable {
        balances[address(0)][msg.sender] += msg.value;
        emit Deposit(address(0), msg.sender, msg.value, balances[address(0)][msg.sender]);
    }

    function depositToken(address token, uint256 amount) external {
        require(token != address(0), "Invalid token");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[token][msg.sender] += amount;
        emit Deposit(token, msg.sender, amount, balances[token][msg.sender]);
    }

    function withdraw(uint256 amount) external {
        require(balances[address(0)][msg.sender] >= amount, "Insufficient balance");
        balances[address(0)][msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(address(0), msg.sender, amount, balances[address(0)][msg.sender]);
    }

    function withdrawToken(address token, uint256 amount) external {
        require(token != address(0), "Invalid token");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");
        balances[token][msg.sender] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
        emit Withdraw(token, msg.sender, amount, balances[token][msg.sender]);
    }

    function balanceOf(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    function placeOrder(
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint64 expires,
        uint32 nonce
    ) external returns (bytes32) {
        require(expires > block.timestamp, "Order expired");
        require(balances[tokenGive][msg.sender] >= amountGive, "Insufficient balance");

        bytes32 orderHash = keccak256(abi.encodePacked(
            address(this),
            msg.sender,
            tokenGet,
            amountGet,
            tokenGive,
            amountGive,
            expires,
            nonce
        ));

        orders[orderHash] = Order({
            maker: msg.sender,
            tokenGet: tokenGet,
            amountGet: amountGet,
            tokenGive: tokenGive,
            amountGive: amountGive,
            expires: expires,
            nonce: nonce,
            orderHash: orderHash
        });

        emit OrderPlaced(orderHash, msg.sender, tokenGet, amountGet, tokenGive, amountGive);
        return orderHash;
    }

    function fillOrder(bytes32 orderHash, uint256 amount) external {
        Order storage order = orders[orderHash];
        require(order.maker != address(0), "Order not found");
        require(!orderFilled[orderHash], "Order already filled");
        require(order.expires > block.timestamp, "Order expired");
        require(amount <= order.amountGet, "Amount too large");

        uint256 giveAmount = (amount * order.amountGive) / order.amountGet;
        require(balances[order.tokenGet][msg.sender] >= amount, "Insufficient taker balance");
        require(balances[order.tokenGive][order.maker] >= giveAmount, "Insufficient maker balance");


        uint256 feeAmount = (amount * uint256(feeRate)) / 10000;
        uint256 netAmount = amount - feeAmount;


        balances[order.tokenGet][msg.sender] -= amount;
        balances[order.tokenGet][order.maker] += netAmount;
        balances[order.tokenGet][feeRecipient] += feeAmount;

        balances[order.tokenGive][order.maker] -= giveAmount;
        balances[order.tokenGive][msg.sender] += giveAmount;


        if (amount == order.amountGet) {
            orderFilled[orderHash] = true;
        } else {

            orders[orderHash].amountGet -= amount;
            orders[orderHash].amountGive -= giveAmount;
        }

        emit Trade(orderHash, order.maker, msg.sender, order.tokenGet, amount, order.tokenGive, giveAmount);
    }

    function cancelOrder(bytes32 orderHash) external {
        Order storage order = orders[orderHash];
        require(order.maker == msg.sender, "Not order maker");
        require(!orderFilled[orderHash], "Order already filled");

        orderFilled[orderHash] = true;
        emit OrderCancelled(orderHash, msg.sender);
    }

    function setFeeRate(uint16 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee rate too high");
        feeRate = _feeRate;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid address");
        feeRecipient = _feeRecipient;
    }

    function getOrder(bytes32 orderHash) external view returns (
        address maker,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint64 expires,
        uint32 nonce,
        bool filled
    ) {
        Order storage order = orders[orderHash];
        return (
            order.maker,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive,
            order.expires,
            order.nonce,
            orderFilled[orderHash]
        );
    }

    function isOrderValid(bytes32 orderHash) external view returns (bool) {
        Order storage order = orders[orderHash];
        return order.maker != address(0) &&
               !orderFilled[orderHash] &&
               order.expires > block.timestamp &&
               balances[order.tokenGive][order.maker] >= order.amountGive;
    }
}
