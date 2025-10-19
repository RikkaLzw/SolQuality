
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidityPoolContract {

    mapping(address => uint256) public userLiquidityTokenA;
    mapping(address => uint256) public userLiquidityTokenB;
    mapping(address => uint256) public userLPTokens;


    address public tokenA;
    address public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLPSupply;
    string public name;
    string public symbol;
    uint8 public decimals;


    uint256 public feeRate = 30;
    uint256 public minimumLiquidity = 1000;

    mapping(address => mapping(address => uint256)) public allowances;

    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address _tokenA, address _tokenB, string memory _name, string memory _symbol) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        name = _name;
        symbol = _symbol;
        decimals = 18;
    }


    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lpTokens) {

        require(msg.sender != address(0), "Invalid address");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        require(amountA > 0 && amountB > 0, "Amounts must be positive");


        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        if (totalLPSupply == 0) {

            lpTokens = sqrt(amountA * amountB) - 1000;
            totalLPSupply = lpTokens + 1000;
        } else {
            uint256 lpFromA = (amountA * totalLPSupply) / reserveA;
            uint256 lpFromB = (amountB * totalLPSupply) / reserveB;
            lpTokens = lpFromA < lpFromB ? lpFromA : lpFromB;
            totalLPSupply += lpTokens;
        }

        userLPTokens[msg.sender] += lpTokens;
        userLiquidityTokenA[msg.sender] += amountA;
        userLiquidityTokenB[msg.sender] += amountB;

        reserveA += amountA;
        reserveB += amountB;

        emit AddLiquidity(msg.sender, amountA, amountB, lpTokens);
        emit Transfer(address(0), msg.sender, lpTokens);
    }


    function removeLiquidity(uint256 lpTokens) external returns (uint256 amountA, uint256 amountB) {

        require(msg.sender != address(0), "Invalid address");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        require(lpTokens > 0, "LP tokens must be positive");
        require(userLPTokens[msg.sender] >= lpTokens, "Insufficient LP tokens");

        amountA = (lpTokens * reserveA) / totalLPSupply;
        amountB = (lpTokens * reserveB) / totalLPSupply;

        userLPTokens[msg.sender] -= lpTokens;
        userLiquidityTokenA[msg.sender] -= amountA;
        userLiquidityTokenB[msg.sender] -= amountB;
        totalLPSupply -= lpTokens;

        reserveA -= amountA;
        reserveB -= amountB;


        require(IERC20(tokenA).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountB), "Transfer B failed");

        emit RemoveLiquidity(msg.sender, amountA, amountB, lpTokens);
        emit Transfer(msg.sender, address(0), lpTokens);
    }


    function swapAForB(uint256 amountAIn) external returns (uint256 amountBOut) {

        require(msg.sender != address(0), "Invalid address");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        require(amountAIn > 0, "Amount must be positive");


        uint256 amountAInWithFee = amountAIn * (10000 - 30) / 10000;
        amountBOut = (amountAInWithFee * reserveB) / (reserveA + amountAInWithFee);

        require(amountBOut > 0, "Insufficient output amount");
        require(reserveB > amountBOut, "Insufficient liquidity");


        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountBOut), "Transfer B failed");

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, tokenA, amountAIn, tokenB, amountBOut);
    }


    function swapBForA(uint256 amountBIn) external returns (uint256 amountAOut) {

        require(msg.sender != address(0), "Invalid address");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        require(amountBIn > 0, "Amount must be positive");


        uint256 amountBInWithFee = amountBIn * (10000 - 30) / 10000;
        amountAOut = (amountBInWithFee * reserveA) / (reserveB + amountBInWithFee);

        require(amountAOut > 0, "Insufficient output amount");
        require(reserveA > amountAOut, "Insufficient liquidity");


        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn), "Transfer B failed");
        require(IERC20(tokenA).transfer(msg.sender, amountAOut), "Transfer A failed");

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, tokenB, amountBIn, tokenA, amountAOut);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be positive");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }


    function getAmountOutAForB(uint256 amountAIn) public view returns (uint256 amountBOut) {
        require(amountAIn > 0, "Amount must be positive");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");


        uint256 amountAInWithFee = amountAIn * (10000 - 30) / 10000;
        amountBOut = (amountAInWithFee * reserveB) / (reserveA + amountAInWithFee);
    }


    function getAmountOutBForA(uint256 amountBIn) public view returns (uint256 amountAOut) {
        require(amountBIn > 0, "Amount must be positive");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");


        uint256 amountBInWithFee = amountBIn * (10000 - 30) / 10000;
        amountAOut = (amountBInWithFee * reserveA) / (reserveB + amountBInWithFee);
    }


    function balanceOf(address account) public view returns (uint256) {
        return userLPTokens[account];
    }

    function totalSupply() public view returns (uint256) {
        return totalLPSupply;
    }


    function transfer(address to, uint256 amount) public returns (bool) {

        require(msg.sender != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");

        require(userLPTokens[msg.sender] >= amount, "Insufficient balance");

        userLPTokens[msg.sender] -= amount;
        userLPTokens[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) public returns (bool) {

        require(from != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");
        require(msg.sender != address(0), "Invalid caller");

        require(userLPTokens[from] >= amount, "Insufficient balance");
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");

        userLPTokens[from] -= amount;
        userLPTokens[to] += amount;
        allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {

        require(msg.sender != address(0), "Invalid owner");
        require(spender != address(0), "Invalid spender");

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }


    function getPrice() public view returns (uint256 priceAInB, uint256 priceBInA) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");


        priceAInB = (reserveB * 1000000) / reserveA;
        priceBInA = (reserveA * 1000000) / reserveB;
    }


    function getPriceAInB() public view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");
        return (reserveB * 1000000) / reserveA;
    }

    function getPriceBInA() public view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");
        return (reserveA * 1000000) / reserveB;
    }


    function updateFeeRate(uint256 newFeeRate) external {

        require(msg.sender == 0x1234567890123456789012345678901234567890, "Not admin");
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function updateMinimumLiquidity(uint256 newMinLiquidity) external {

        require(msg.sender == 0x1234567890123456789012345678901234567890, "Not admin");
        require(newMinLiquidity > 0, "Must be positive");
        minimumLiquidity = newMinLiquidity;
    }


    function emergencyWithdraw(address token, uint256 amount) external {

        require(msg.sender == 0x1234567890123456789012345678901234567890, "Not admin");
        require(token != address(0), "Invalid token");
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
    }


    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }


    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }


    function getReserves() public view returns (uint256, uint256) {
        require(reserveA >= 0 && reserveB >= 0, "Invalid reserves");
        return (reserveA, reserveB);
    }

    function getLiquidityInfo(address user) public view returns (uint256 lpBalance, uint256 shareA, uint256 shareB) {
        require(user != address(0), "Invalid user");

        lpBalance = userLPTokens[user];
        if (totalLPSupply > 0) {
            shareA = (lpBalance * reserveA) / totalLPSupply;
            shareB = (lpBalance * reserveB) / totalLPSupply;
        }
    }


    function getUserShareA(address user) public view returns (uint256) {
        require(user != address(0), "Invalid user");
        if (totalLPSupply == 0) return 0;
        return (userLPTokens[user] * reserveA) / totalLPSupply;
    }

    function getUserShareB(address user) public view returns (uint256) {
        require(user != address(0), "Invalid user");
        if (totalLPSupply == 0) return 0;
        return (userLPTokens[user] * reserveB) / totalLPSupply;
    }
}
