
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

    address public tokenA;
    address public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;


    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    address internal owner;
    bool internal initialized;

    string public name = "Liquidity Pool Token";
    string public symbol = "LPT";
    uint8 public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Swap(address indexed user, uint256 amountAIn, uint256 amountBIn, uint256 amountAOut, uint256 amountBOut);
    event Sync(uint256 reserveA, uint256 reserveB);

    constructor() {
        owner = msg.sender;
    }


    function initialize(address _tokenA, address _tokenB) external {

        require(msg.sender == owner, "Not owner");
        require(!initialized, "Already initialized");

        tokenA = _tokenA;
        tokenB = _tokenB;
        initialized = true;
    }


    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {

        require(initialized, "Not initialized");
        require(amountADesired > 0, "Amount A must be positive");
        require(amountBDesired > 0, "Amount B must be positive");


        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }


        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


        if (totalSupply == 0) {
            liquidity = sqrt(amountA * amountB) - 1000;
            balanceOf[address(0)] = 1000;
        } else {
            liquidity = min((amountA * totalSupply) / reserveA, (amountB * totalSupply) / reserveB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        totalSupply += liquidity;
        balanceOf[to] += liquidity;
        reserveA += amountA;
        reserveB += amountB;

        emit Transfer(address(0), to, liquidity);
        emit Mint(to, liquidity);
        emit Sync(reserveA, reserveB);
    }


    function removeLiquidity(uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to) external returns (uint256 amountA, uint256 amountB) {

        require(initialized, "Not initialized");
        require(liquidity > 0, "Invalid liquidity amount");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");


        uint256 totalSupplyLocal = totalSupply;
        amountA = (liquidity * reserveA) / totalSupplyLocal;
        amountB = (liquidity * reserveB) / totalSupplyLocal;

        require(amountA >= amountAMin, "Insufficient A amount");
        require(amountB >= amountBMin, "Insufficient B amount");


        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;


        require(IERC20(tokenA).transfer(to, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(to, amountB), "Transfer B failed");

        emit Transfer(msg.sender, address(0), liquidity);
        emit Burn(msg.sender, liquidity);
        emit Sync(reserveA, reserveB);
    }


    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to) external returns (uint256[] memory amounts) {

        require(initialized, "Not initialized");
        require(path.length == 2, "Invalid path");
        require(path[0] == tokenA || path[0] == tokenB, "Invalid input token");
        require(path[1] == tokenA || path[1] == tokenB, "Invalid output token");
        require(path[0] != path[1], "Same token");
        require(amountIn > 0, "Invalid input amount");

        amounts = new uint256[](2);
        amounts[0] = amountIn;


        uint256 reserveIn;
        uint256 reserveOut;

        if (path[0] == tokenA) {
            reserveIn = reserveA;
            reserveOut = reserveB;
        } else {
            reserveIn = reserveB;
            reserveOut = reserveA;
        }


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amounts[1] = numerator / denominator;

        require(amounts[1] >= amountOutMin, "Insufficient output amount");
        require(amounts[1] < reserveOut, "Insufficient liquidity");


        require(IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]), "Transfer in failed");
        require(IERC20(path[1]).transfer(to, amounts[1]), "Transfer out failed");


        if (path[0] == tokenA) {
            reserveA += amounts[0];
            reserveB -= amounts[1];
        } else {
            reserveB += amounts[0];
            reserveA -= amounts[1];
        }

        emit Swap(msg.sender, path[0] == tokenA ? amounts[0] : 0, path[0] == tokenB ? amounts[0] : 0, path[1] == tokenA ? amounts[1] : 0, path[1] == tokenB ? amounts[1] : 0);
        emit Sync(reserveA, reserveB);
    }


    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to) external returns (uint256[] memory amounts) {

        require(initialized, "Not initialized");
        require(path.length == 2, "Invalid path");
        require(path[0] == tokenA || path[0] == tokenB, "Invalid input token");
        require(path[1] == tokenA || path[1] == tokenB, "Invalid output token");
        require(path[0] != path[1], "Same token");
        require(amountOut > 0, "Invalid output amount");

        amounts = new uint256[](2);
        amounts[1] = amountOut;


        uint256 reserveIn;
        uint256 reserveOut;

        if (path[0] == tokenA) {
            reserveIn = reserveA;
            reserveOut = reserveB;
        } else {
            reserveIn = reserveB;
            reserveOut = reserveA;
        }

        require(amountOut < reserveOut, "Insufficient liquidity");


        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amounts[0] = (numerator / denominator) + 1;

        require(amounts[0] <= amountInMax, "Excessive input amount");


        require(IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]), "Transfer in failed");
        require(IERC20(path[1]).transfer(to, amounts[1]), "Transfer out failed");


        if (path[0] == tokenA) {
            reserveA += amounts[0];
            reserveB -= amounts[1];
        } else {
            reserveB += amounts[0];
            reserveA -= amounts[1];
        }

        emit Swap(msg.sender, path[0] == tokenA ? amounts[0] : 0, path[0] == tokenB ? amounts[0] : 0, path[1] == tokenA ? amounts[1] : 0, path[1] == tokenB ? amounts[1] : 0);
        emit Sync(reserveA, reserveB);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountIn) {
        require(amountOut > 0, "Invalid output amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        require(amountOut < reserveOut, "Insufficient liquidity");


        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }


    function sync() external {

        require(initialized, "Not initialized");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        reserveA = balanceA;
        reserveB = balanceB;

        emit Sync(reserveA, reserveB);
    }


    function emergencyWithdraw(address token, uint256 amount, address to) external {

        require(msg.sender == owner, "Not owner");
        require(to != address(0), "Invalid recipient");

        if (amount == 0) {
            amount = IERC20(token).balanceOf(address(this));
        }

        require(IERC20(token).transfer(to, amount), "Transfer failed");
    }


    function setOwner(address newOwner) external {

        require(msg.sender == owner, "Not owner");
        require(newOwner != address(0), "Invalid address");

        owner = newOwner;
    }


    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }


    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(from != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }


    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "Invalid spender");

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }


    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }


    function getTokens() external view returns (address _tokenA, address _tokenB) {
        _tokenA = tokenA;
        _tokenB = tokenB;
    }


    function getLiquidityValue(address user) external view returns (uint256 valueA, uint256 valueB) {
        uint256 userBalance = balanceOf[user];
        if (userBalance == 0 || totalSupply == 0) {
            return (0, 0);
        }


        valueA = (userBalance * reserveA) / totalSupply;
        valueB = (userBalance * reserveB) / totalSupply;
    }
}
