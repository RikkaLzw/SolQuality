
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DEXTradingContract {
mapping(address => mapping(address => uint256)) public a;
    mapping(address => uint256) public b;
uint256 private c = 997;
  address public d;

    event e(address indexed f, address indexed g, uint256 h, uint256 i);
event j(address indexed k, address indexed l, uint256 m, uint256 n);
    event o(address indexed p, uint256 q, uint256 r);

    constructor() {
d = msg.sender;
    }

function addliquidity(address s, address t, uint256 u, uint256 v) external {
        require(s != address(0) && t != address(0), "Invalid token");
require(u > 0 && v > 0, "Invalid amounts");

        IERC20(s).transferFrom(msg.sender, address(this), u); IERC20(t).transferFrom(msg.sender, address(this), v);

uint256 w = u * v;
        a[s][t] += u;
a[t][s] += v; b[msg.sender] += w;

        emit e(msg.sender, s, u, v);
}

    function removeliquidity(address x, address y, uint256 z) external {
require(z > 0 && b[msg.sender] >= z, "Invalid amount");

        uint256 temp1 = a[x][y];
uint256 temp2 = a[y][x];
        uint256 temp3 = (temp1 * z) / (temp1 * temp2);
uint256 temp4 = (temp2 * z) / (temp1 * temp2);

a[x][y] -= temp3; a[y][x] -= temp4;
        b[msg.sender] -= z;

IERC20(x).transfer(msg.sender, temp3); IERC20(y).transfer(msg.sender, temp4);

        emit j(msg.sender, x, temp3, temp4);
    }

function swapTokens(address tokenin, address tokenout, uint256 amountin) external {
        require(tokenin != address(0) && tokenout != address(0), "Invalid tokens");
require(amountin > 0, "Invalid amount");
        require(a[tokenin][tokenout] > 0 && a[tokenout][tokenin] > 0, "No liquidity");

        uint256 fee = (amountin * (1000 - c)) / 1000;
uint256 amountinfee = amountin - fee;

        uint256 reservein = a[tokenin][tokenout];
uint256 reserveout = a[tokenout][tokenin];
        uint256 amountout = (reserveout * amountinfee) / (reservein + amountinfee);

        require(amountout > 0 && amountout < reserveout, "Invalid output");

IERC20(tokenin).transferFrom(msg.sender, address(this), amountin);

a[tokenin][tokenout] += amountin; a[tokenout][tokenin] -= amountout;

        IERC20(tokenout).transfer(msg.sender, amountout);

emit o(msg.sender, amountin, amountout);
    }

    function getPrice(address token1, address token2, uint256 amount) external view returns (uint256) {
if (a[token1][token2] == 0 || a[token2][token1] == 0) return 0;

        uint256 fee = (amount * (1000 - c)) / 1000;
uint256 amountfee = amount - fee;

uint256 reserve1 = a[token1][token2]; uint256 reserve2 = a[token2][token1];

        return (reserve2 * amountfee) / (reserve1 + amountfee);
}

function emergencyWithdraw(address token) external {
        require(msg.sender == d, "Not authorized");

uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
IERC20(token).transfer(d, balance);
        }
    }

    function updateFee(uint256 newfee) external {
require(msg.sender == d, "Not authorized"); require(newfee <= 1000, "Invalid fee");

c = newfee;
    }

function getLiquidityBalance(address user) external view returns (uint256) {
        return b[user];
    }

    function getReserves(address token1, address token2) external view returns (uint256, uint256) {
return (a[token1][token2], a[token2][token1]);
    }
}
