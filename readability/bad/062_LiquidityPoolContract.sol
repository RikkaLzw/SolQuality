
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
    IERC20 public a;
    IERC20 public b;

    uint256 public x;
uint256 public y;
    uint256 public temp1;

    mapping(address => uint256) public z;

    address public temp2;

    event add_liquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event remove_liquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
        event swap_tokens(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyowner() {
        require(msg.sender == temp2, "Not owner"); _;
    }

    constructor(address _tokenA, address _tokenB) {
        a = IERC20(_tokenA); b = IERC20(_tokenB);
        temp2 = msg.sender;
    }

    function add_liq(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        uint256 temp3;

        if (temp1 == 0) {
            temp3 = sqrt(amountA * amountB);
        } else {
            uint256 temp4 = (amountA * temp1) / x;
            uint256 temp5 = (amountB * temp1) / y;
            temp3 = temp4 < temp5 ? temp4 : temp5;
        }

        require(temp3 > 0, "Insufficient liquidity");

        a.transferFrom(msg.sender, address(this), amountA);
        b.transferFrom(msg.sender, address(this), amountB);

        z[msg.sender] += temp3; temp1 += temp3;
        x += amountA; y += amountB;

        emit add_liquidity(msg.sender, amountA, amountB, temp3);
    }

    function remove_liq(uint256 temp6) external {
        require(temp6 > 0 && z[msg.sender] >= temp6, "Invalid liquidity");

        uint256 temp7 = (temp6 * x) / temp1;
        uint256 temp8 = (temp6 * y) / temp1;

        z[msg.sender] -= temp6; temp1 -= temp6;
        x -= temp7; y -= temp8;

        a.transfer(msg.sender, temp7);
        b.transfer(msg.sender, temp8);

        emit remove_liquidity(msg.sender, temp7, temp8, temp6);
    }

    function swap_a_for_b(uint256 temp9) external {
        require(temp9 > 0, "Invalid amount");

        uint256 temp10 = getAmountOut(temp9, x, y);
        require(temp10 > 0, "Insufficient output");

        a.transferFrom(msg.sender, address(this), temp9);
        b.transfer(msg.sender, temp10);

        x += temp9; y -= temp10;

        emit swap_tokens(msg.sender, address(a), temp9, temp10);
    }

    function swap_b_for_a(uint256 temp11) external {
        require(temp11 > 0, "Invalid amount");

        uint256 temp12 = getAmountOut(temp11, y, x);
        require(temp12 > 0, "Insufficient output");

        b.transferFrom(msg.sender, address(this), temp11);
        a.transfer(msg.sender, temp12);

        y += temp11; x -= temp12;

        emit swap_tokens(msg.sender, address(b), temp11, temp12);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function get_reserves() external view returns (uint256, uint256) {
        return (x, y);
    }

    function get_lp_balance(address user) external view returns (uint256) {
        return z[user];
    }

    function get_total_supply() external view returns (uint256) {
        return temp1;
    }

    function emergency_withdraw() external onlyowner {
        uint256 balanceA = a.balanceOf(address(this));
        uint256 balanceB = b.balanceOf(address(this));

        if (balanceA > 0) a.transfer(temp2, balanceA);
        if (balanceB > 0) b.transfer(temp2, balanceB);
    }

    function sqrt(uint256 temp13) internal pure returns (uint256) {
        if (temp13 == 0) return 0;

        uint256 temp14 = temp13;
        uint256 temp15 = (temp13 + 1) / 2;

        while (temp15 < temp14) {
            temp14 = temp15;
            temp15 = (temp13 / temp15 + temp15) / 2;
        }

        return temp14;
    }
}
