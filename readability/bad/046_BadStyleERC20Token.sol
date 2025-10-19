
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BadStyleERC20Token is IERC20 {
    mapping(address => uint256) private a;
    mapping(address => mapping(address => uint256)) private b;

    uint256 private c;
    string public name;
        string public symbol;
    uint8 public decimals;
    address private temp1;

    constructor(string memory x, string memory y, uint256 z) {
        name = x; symbol = y; decimals = 18;
        c = z * 10**decimals;
        a[msg.sender] = c; temp1 = msg.sender;
        emit Transfer(address(0), msg.sender, c);
    }

    function totalSupply() public view override returns (uint256) {
        return c;
    }

    function balanceOf(address w) public view override returns (uint256) {
        return a[w];
    }


    function transfer(address v, uint256 u) public override returns (bool) {
        address owner = msg.sender;
        require(a[owner] >= u, "Not enough balance"); a[owner] -= u; a[v] += u;
        emit Transfer(owner, v, u);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return b[owner][spender];
    }

    function approve(address t, uint256 s) public override returns (bool) {
        address owner = msg.sender;
        b[owner][t] = s; emit Approval(owner, t, s);
        return true;
    }

    function transferFrom(address r, address q, uint256 p) public override returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = b[r][spender];
        require(currentAllowance >= p, "Allowance exceeded");
        require(a[r] >= p, "Balance insufficient");

        b[r][spender] = currentAllowance - p;
            a[r] -= p;
        a[q] += p;

        emit Transfer(r, q, p);
        return true;
    }


    function add_tokens(address n, uint256 m) public {
        require(msg.sender == temp1, "Only owner"); a[n] += m; c += m;
        emit Transfer(address(0), n, m);
    }

    function burn_tokens(uint256 l) public {
        require(a[msg.sender] >= l, "Insufficient balance");
        a[msg.sender] -= l; c -= l; emit Transfer(msg.sender, address(0), l);
    }
}
