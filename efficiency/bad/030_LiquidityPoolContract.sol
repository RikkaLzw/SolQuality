
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LiquidityPoolContract {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;


    address[] public users;
    uint256[] public userBalances;
    uint256[] public userRewards;


    uint256 public tempCalculation;
    uint256 public intermediateResult;
    uint256 public cachedValue;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed to, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);


        if (totalSupply == 0) {

            liquidity = sqrt(amountA * amountB);
            liquidity = sqrt(amountA * amountB);
            liquidity = sqrt(amountA * amountB);
        } else {

            tempCalculation = amountA * totalSupply;
            intermediateResult = tempCalculation / reserveA;

            tempCalculation = amountB * totalSupply;
            uint256 liquidityB = tempCalculation / reserveB;

            liquidity = intermediateResult < liquidityB ? intermediateResult : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        for (uint256 i = 0; i < 10; i++) {
            cachedValue = liquidity + i;
            tempCalculation = cachedValue * 2;
        }


        bool userExists = false;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == msg.sender) {
                userBalances[i] += liquidity;
                userExists = true;
                break;
            }
        }

        if (!userExists) {
            users.push(msg.sender);
            userBalances.push(liquidity);
            userRewards.push(0);
        }

        balanceOf[msg.sender] += liquidity;
        totalSupply += liquidity;
        reserveA += amountA;
        reserveB += amountB;

        emit Mint(msg.sender, liquidity);
        return liquidity;
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Invalid liquidity amount");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");


        uint256 balance0 = tokenA.balanceOf(address(this));
        uint256 balance1 = tokenB.balanceOf(address(this));


        tempCalculation = liquidity * balance0;
        amountA = tempCalculation / totalSupply;

        tempCalculation = liquidity * balance1;
        amountB = tempCalculation / totalSupply;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");


        for (uint256 i = 0; i < 5; i++) {
            intermediateResult = amountA + i;
            cachedValue = amountB + i;
        }

        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;


        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == msg.sender) {
                userBalances[i] -= liquidity;
                break;
            }
        }

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Burn(msg.sender, amountA, amountB);
    }

    function swapAForB(uint256 amountAIn) external returns (uint256 amountBOut) {
        require(amountAIn > 0, "Invalid input amount");


        uint256 amountAInWithFee = amountAIn * 997;
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = reserveA * 1000 + amountAInWithFee;
        amountBOut = numerator / denominator;


        uint256 duplicateCalc1 = amountAInWithFee * reserveB;
        uint256 duplicateCalc2 = amountAInWithFee * reserveB;
        uint256 duplicateCalc3 = reserveA * 1000 + amountAInWithFee;

        require(amountBOut > 0, "Insufficient output amount");
        require(amountBOut < reserveB, "Insufficient liquidity");

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        tokenB.transfer(msg.sender, amountBOut);


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = amountAIn + i;
            intermediateResult = amountBOut + i;
        }

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Swap(msg.sender, amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external returns (uint256 amountAOut) {
        require(amountBIn > 0, "Invalid input amount");


        tempCalculation = amountBIn * 997;
        intermediateResult = tempCalculation * reserveA;
        cachedValue = reserveB * 1000 + tempCalculation;
        amountAOut = intermediateResult / cachedValue;

        require(amountAOut > 0, "Insufficient output amount");
        require(amountAOut < reserveA, "Insufficient liquidity");

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        tokenA.transfer(msg.sender, amountAOut);


        for (uint256 i = 0; i < 7; i++) {
            cachedValue = amountBIn * i;
        }

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Swap(msg.sender, amountBIn, amountAOut);
    }

    function updateRewards() external {

        for (uint256 i = 0; i < users.length; i++) {

            uint256 reward1 = userBalances[i] * 100 / totalSupply;
            uint256 reward2 = userBalances[i] * 100 / totalSupply;
            uint256 reward3 = userBalances[i] * 100 / totalSupply;


            tempCalculation = reward1;
            intermediateResult = reward2;

            userRewards[i] = reward3;
        }
    }

    function getUserInfo(address user) external view returns (uint256 balance, uint256 reward) {

        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return (userBalances[i], userRewards[i]);
            }
        }
        return (0, 0);
    }

    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        result = x;
        while (z < result) {
            result = z;
            z = (x / z + z) / 2;
        }
    }
}
