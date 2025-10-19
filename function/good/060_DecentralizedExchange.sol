
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
    mapping(address => mapping(address => uint256)) public orders;
    mapping(bytes32 => bool) public completedOrders;

    address public feeRecipient;
    uint256 public feeRate = 25;
    uint256 constant FEE_DENOMINATOR = 10000;

    event Deposit(address indexed token, address indexed user, uint256 amount);
    event Withdraw(address indexed token, address indexed user, uint256 amount);
    event OrderPlaced(bytes32 indexed orderHash, address indexed user, address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet);
    event Trade(bytes32 indexed orderHash, address indexed user, address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet);

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }

    function depositToken(address token, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[token][msg.sender] += amount;

        emit Deposit(token, msg.sender, amount);
    }

    function withdrawToken(address token, uint256 amount) external {
        require(balances[token][msg.sender] >= amount, "Insufficient balance");

        balances[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(token, msg.sender, amount);
    }

    function placeOrder(address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet) external {
        require(tokenGive != tokenGet, "Cannot trade same token");
        require(amountGive > 0 && amountGet > 0, "Amounts must be greater than 0");
        require(balances[tokenGive][msg.sender] >= amountGive, "Insufficient balance");

        bytes32 orderHash = _getOrderHash(msg.sender, tokenGive, amountGive, tokenGet, amountGet);
        orders[msg.sender][orderHash] = amountGive;

        emit OrderPlaced(orderHash, msg.sender, tokenGive, amountGive, tokenGet, amountGet);
    }

    function executeOrder(address user, address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet) external {
        bytes32 orderHash = _getOrderHash(user, tokenGive, amountGive, tokenGet, amountGet);
        require(!completedOrders[orderHash], "Order already completed");
        require(orders[user][orderHash] == amountGive, "Order does not exist");

        _executeTrade(user, msg.sender, tokenGive, amountGive, tokenGet, amountGet, orderHash);
    }

    function cancelOrder(address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet) external {
        bytes32 orderHash = _getOrderHash(msg.sender, tokenGive, amountGive, tokenGet, amountGet);
        require(orders[msg.sender][orderHash] == amountGive, "Order does not exist");

        orders[msg.sender][orderHash] = 0;
    }

    function getBalance(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    function _executeTrade(address maker, address taker, address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet, bytes32 orderHash) internal {
        require(balances[tokenGive][maker] >= amountGive, "Maker insufficient balance");
        require(balances[tokenGet][taker] >= amountGet, "Taker insufficient balance");

        uint256 feeAmount = _calculateFee(amountGet);
        uint256 netAmount = amountGet - feeAmount;

        balances[tokenGive][maker] -= amountGive;
        balances[tokenGive][taker] += amountGive;

        balances[tokenGet][taker] -= amountGet;
        balances[tokenGet][maker] += netAmount;
        balances[tokenGet][feeRecipient] += feeAmount;

        completedOrders[orderHash] = true;
        orders[maker][orderHash] = 0;

        emit Trade(orderHash, maker, tokenGive, amountGive, tokenGet, amountGet);
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeRate) / FEE_DENOMINATOR;
    }

    function _getOrderHash(address user, address tokenGive, uint256 amountGive, address tokenGet, uint256 amountGet) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, tokenGive, amountGive, tokenGet, amountGet));
    }
}
