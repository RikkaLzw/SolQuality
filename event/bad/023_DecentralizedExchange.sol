
pragma solidity ^0.8.0;

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
    mapping(bytes32 => bool) public executedOrders;

    address public owner;
    uint256 public feeRate = 30;
    uint256 constant FEE_DENOMINATOR = 10000;

    error InvalidAmount();
    error InsufficientBalance();
    error OrderExists();
    error Unauthorized();

    event Deposit(address token, address user, uint256 amount);
    event Withdraw(address token, address user, uint256 amount);
    event OrderPlaced(address user, address tokenA, address tokenB, uint256 amountA);
    event OrderExecuted(bytes32 orderHash, address buyer, address seller);
    event FeeCollected(address token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit(address token, uint256 amount) external {
        require(amount > 0);
        require(token != address(0));

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[token][msg.sender] += amount;


    }

    function withdraw(address token, uint256 amount) external {
        require(amount > 0);
        require(balances[token][msg.sender] >= amount);

        balances[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);


    }

    function placeOrder(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        require(amountA > 0);
        require(amountB > 0);
        require(balances[tokenA][msg.sender] >= amountA);

        bytes32 orderHash = keccak256(abi.encodePacked(
            msg.sender, tokenA, tokenB, amountA, amountB, block.timestamp
        ));

        require(!executedOrders[orderHash]);

        orders[tokenA][tokenB] = amountA;
        balances[tokenA][msg.sender] -= amountA;

        emit OrderPlaced(msg.sender, tokenA, tokenB, amountA);
    }

    function executeOrder(
        address seller,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        require(orders[tokenA][tokenB] >= amountA);
        require(balances[tokenB][msg.sender] >= amountB);

        bytes32 orderHash = keccak256(abi.encodePacked(
            seller, tokenA, tokenB, amountA, amountB, block.timestamp
        ));

        require(!executedOrders[orderHash]);

        uint256 feeA = (amountA * feeRate) / FEE_DENOMINATOR;
        uint256 feeB = (amountB * feeRate) / FEE_DENOMINATOR;

        orders[tokenA][tokenB] -= amountA;
        balances[tokenB][msg.sender] -= amountB;

        balances[tokenA][msg.sender] += (amountA - feeA);
        balances[tokenB][seller] += (amountB - feeB);

        balances[tokenA][owner] += feeA;
        balances[tokenB][owner] += feeB;

        executedOrders[orderHash] = true;

        emit OrderExecuted(orderHash, msg.sender, seller);
    }

    function cancelOrder(address tokenA, address tokenB, uint256 amount) external {
        require(orders[tokenA][tokenB] >= amount);

        orders[tokenA][tokenB] -= amount;
        balances[tokenA][msg.sender] += amount;


    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        require(amountIn > 0);
        require(balances[tokenIn][msg.sender] >= amountIn);

        uint256 amountOut = getAmountOut(amountIn, tokenIn, tokenOut);
        require(amountOut >= minAmountOut);

        uint256 fee = (amountOut * feeRate) / FEE_DENOMINATOR;
        uint256 amountOutAfterFee = amountOut - fee;

        balances[tokenIn][msg.sender] -= amountIn;
        balances[tokenOut][msg.sender] += amountOutAfterFee;
        balances[tokenOut][owner] += fee;


    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256) {
        uint256 reserveIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 reserveOut = IERC20(tokenOut).balanceOf(address(this));

        require(reserveIn > 0 && reserveOut > 0);

        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        require(amountA > 0 && amountB > 0);
        require(balances[tokenA][msg.sender] >= amountA);
        require(balances[tokenB][msg.sender] >= amountB);

        balances[tokenA][msg.sender] -= amountA;
        balances[tokenB][msg.sender] -= amountB;


    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external {
        require(liquidity > 0);

        uint256 totalSupply = IERC20(tokenA).balanceOf(address(this)) +
                             IERC20(tokenB).balanceOf(address(this));

        uint256 amountA = (liquidity * IERC20(tokenA).balanceOf(address(this))) / totalSupply;
        uint256 amountB = (liquidity * IERC20(tokenB).balanceOf(address(this))) / totalSupply;

        balances[tokenA][msg.sender] += amountA;
        balances[tokenB][msg.sender] += amountB;


    }

    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000);
        feeRate = newFeeRate;


    }

    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);


    }

    function getBalance(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    function getOrderAmount(address tokenA, address tokenB) external view returns (uint256) {
        return orders[tokenA][tokenB];
    }
}
