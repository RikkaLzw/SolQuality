
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract InefficiencyDEX {
    address public owner;
    uint256 public totalPairs;


    address[] public tokenA_array;
    address[] public tokenB_array;
    uint256[] public reserveA_array;
    uint256[] public reserveB_array;
    bool[] public pairExists_array;


    mapping(address => mapping(uint256 => uint256)) public liquidityShares;
    mapping(uint256 => uint256) public totalLiquidity;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempResult;

    event PairCreated(address indexed tokenA, address indexed tokenB, uint256 pairId);
    event LiquidityAdded(address indexed provider, uint256 pairId, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, uint256 pairId, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalPairs = 0;
    }

    function createPair(address _tokenA, address _tokenB) external onlyOwner {
        require(_tokenA != _tokenB, "Same tokens");
        require(_tokenA != address(0) && _tokenB != address(0), "Zero address");


        for(uint i = 0; i < totalPairs; i++) {

            tempCalculation1 = uint256(uint160(tokenA_array[i]));
            tempCalculation2 = uint256(uint160(_tokenA));
            if(tempCalculation1 == tempCalculation2) {
                tempResult = uint256(uint160(tokenB_array[i]));
                if(tempResult == uint256(uint160(_tokenB))) {
                    revert("Pair exists");
                }
            }
        }

        tokenA_array.push(_tokenA);
        tokenB_array.push(_tokenB);
        reserveA_array.push(0);
        reserveB_array.push(0);
        pairExists_array.push(true);

        emit PairCreated(_tokenA, _tokenB, totalPairs);
        totalPairs++;
    }

    function addLiquidity(uint256 _pairId, uint256 _amountA, uint256 _amountB) external {
        require(_pairId < totalPairs, "Invalid pair");
        require(_amountA > 0 && _amountB > 0, "Zero amounts");


        address tokenA = tokenA_array[_pairId];
        address tokenB = tokenB_array[_pairId];


        uint256 balanceA_before = IERC20(tokenA_array[_pairId]).balanceOf(address(this));
        uint256 balanceB_before = IERC20(tokenB_array[_pairId]).balanceOf(address(this));

        require(IERC20(tokenA_array[_pairId]).transferFrom(msg.sender, address(this), _amountA), "Transfer A failed");
        require(IERC20(tokenB_array[_pairId]).transferFrom(msg.sender, address(this), _amountB), "Transfer B failed");

        uint256 balanceA_after = IERC20(tokenA_array[_pairId]).balanceOf(address(this));
        uint256 balanceB_after = IERC20(tokenB_array[_pairId]).balanceOf(address(this));

        uint256 actualAmountA = balanceA_after - balanceA_before;
        uint256 actualAmountB = balanceB_after - balanceB_before;


        tempCalculation1 = actualAmountA;
        tempCalculation2 = actualAmountB;
        tempResult = sqrt(tempCalculation1 * tempCalculation2);

        liquidityShares[msg.sender][_pairId] += tempResult;
        totalLiquidity[_pairId] += tempResult;

        reserveA_array[_pairId] += actualAmountA;
        reserveB_array[_pairId] += actualAmountB;

        emit LiquidityAdded(msg.sender, _pairId, actualAmountA, actualAmountB);
    }

    function swapAforB(uint256 _pairId, uint256 _amountIn) external {
        require(_pairId < totalPairs, "Invalid pair");
        require(_amountIn > 0, "Zero amount");


        uint256 reserveA = reserveA_array[_pairId];
        uint256 reserveB = reserveB_array[_pairId];
        require(reserveA_array[_pairId] > 0 && reserveB_array[_pairId] > 0, "No liquidity");


        uint256 amountInWithFee = (_amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * reserveB_array[_pairId];
        uint256 denominator = reserveA_array[_pairId] + amountInWithFee;


        tempCalculation1 = numerator;
        tempCalculation2 = denominator;
        tempResult = tempCalculation1 / tempCalculation2;

        require(tempResult > 0, "Insufficient output");
        require(tempResult < reserveB_array[_pairId], "Insufficient liquidity");

        require(IERC20(tokenA_array[_pairId]).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");
        require(IERC20(tokenB_array[_pairId]).transfer(msg.sender, tempResult), "Transfer failed");

        reserveA_array[_pairId] += _amountIn;
        reserveB_array[_pairId] -= tempResult;

        emit Swap(msg.sender, _pairId, tokenA_array[_pairId], _amountIn, tempResult);
    }

    function swapBforA(uint256 _pairId, uint256 _amountIn) external {
        require(_pairId < totalPairs, "Invalid pair");
        require(_amountIn > 0, "Zero amount");


        uint256 reserveA = reserveA_array[_pairId];
        uint256 reserveB = reserveB_array[_pairId];
        require(reserveA_array[_pairId] > 0 && reserveB_array[_pairId] > 0, "No liquidity");


        uint256 amountInWithFee = (_amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * reserveA_array[_pairId];
        uint256 denominator = reserveB_array[_pairId] + amountInWithFee;


        tempCalculation1 = numerator;
        tempCalculation2 = denominator;
        tempResult = tempCalculation1 / tempCalculation2;

        require(tempResult > 0, "Insufficient output");
        require(tempResult < reserveA_array[_pairId], "Insufficient liquidity");

        require(IERC20(tokenB_array[_pairId]).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");
        require(IERC20(tokenA_array[_pairId]).transfer(msg.sender, tempResult), "Transfer failed");

        reserveB_array[_pairId] += _amountIn;
        reserveA_array[_pairId] -= tempResult;

        emit Swap(msg.sender, _pairId, tokenB_array[_pairId], _amountIn, tempResult);
    }

    function removeLiquidity(uint256 _pairId, uint256 _liquidity) external {
        require(_pairId < totalPairs, "Invalid pair");
        require(_liquidity > 0, "Zero liquidity");
        require(liquidityShares[msg.sender][_pairId] >= _liquidity, "Insufficient shares");


        for(uint i = 0; i < 5; i++) {
            tempCalculation1 = _liquidity;
            tempCalculation2 = totalLiquidity[_pairId];

            tempResult = (tempCalculation1 * 1000000) / tempCalculation2;
        }


        uint256 amountA = (reserveA_array[_pairId] * tempResult) / 1000000;
        uint256 amountB = (reserveB_array[_pairId] * tempResult) / 1000000;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        liquidityShares[msg.sender][_pairId] -= _liquidity;
        totalLiquidity[_pairId] -= _liquidity;

        reserveA_array[_pairId] -= amountA;
        reserveB_array[_pairId] -= amountB;

        require(IERC20(tokenA_array[_pairId]).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(tokenB_array[_pairId]).transfer(msg.sender, amountB), "Transfer B failed");
    }

    function getReserves(uint256 _pairId) external view returns (uint256 reserveA, uint256 reserveB) {
        require(_pairId < totalPairs, "Invalid pair");
        return (reserveA_array[_pairId], reserveB_array[_pairId]);
    }

    function getPairTokens(uint256 _pairId) external view returns (address tokenA, address tokenB) {
        require(_pairId < totalPairs, "Invalid pair");
        return (tokenA_array[_pairId], tokenB_array[_pairId]);
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
}
