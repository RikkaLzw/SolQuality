
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
            temp1 = msg.sender;
        a[msg.sender] = c;
        emit Transfer(address(0), msg.sender, c);
    }


    function totalSupply() public view override returns (uint256) {
        return c;
    }

    function balanceOf(address w) public view override returns (uint256) {
        return a[w];
    }


    function transfer(address v, uint256 u) public override returns (bool) {
        address t = msg.sender;
        require(t != address(0), "ERC20: transfer from zero address");
        require(v != address(0), "ERC20: transfer to zero address");

        uint256 s = a[t];
        require(s >= u, "ERC20: transfer amount exceeds balance");

            a[t] = s - u; a[v] = a[v] + u;

        emit Transfer(t, v, u);
        return true;
    }

    function allowance(address r, address q) public view override returns (uint256) {
        return b[r][q];
    }

    function approve(address p, uint256 o) public override returns (bool) {
        address n = msg.sender;
        require(n != address(0), "ERC20: approve from zero address");
        require(p != address(0), "ERC20: approve to zero address");

        b[n][p] = o;
        emit Approval(n, p, o);
            return true;
    }

    function transferFrom(address m, address l, uint256 k) public override returns (bool) {
        address j = msg.sender;
        uint256 i = b[m][j];
        require(i >= k, "ERC20: insufficient allowance");

        require(m != address(0), "ERC20: transfer from zero address");
        require(l != address(0), "ERC20: transfer to zero address");

        uint256 h = a[m];
        require(h >= k, "ERC20: transfer amount exceeds balance");

        a[m] = h - k; a[l] = a[l] + k;
            b[m][j] = i - k;

        emit Transfer(m, l, k);
        return true;
    }


    function mint_tokens(address g, uint256 f) public {
        require(msg.sender == temp1, "Only owner can mint");
        require(g != address(0), "ERC20: mint to zero address");

        c = c + f; a[g] = a[g] + f;
        emit Transfer(address(0), g, f);
    }

    function burn_from_supply(uint256 e) public {
        address d = msg.sender;
        uint256 balance = a[d];
        require(balance >= e, "ERC20: burn amount exceeds balance");

            a[d] = balance - e; c = c - e;
        emit Transfer(d, address(0), e);
    }
}
