
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

    uint256 private x;
    string public name;
        string public symbol;
    uint8 public decimals;
    address private temp1;

    constructor(string memory n, string memory s, uint8 d, uint256 supply) {
        name = n; symbol = s; decimals = d;
        x = supply * 10**d;
        temp1 = msg.sender;
        a[msg.sender] = x;
        emit Transfer(address(0), msg.sender, x);
    }

    function totalSupply() public view override returns (uint256) {
        return x;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return a[account];
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        require(owner != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = a[owner];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

            a[owner] = fromBalance - amount;
        a[to] += amount;

        emit Transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return b[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        require(owner != address(0), "ERC20: approve from the zero address"); require(spender != address(0), "ERC20: approve to the zero address");

        b[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = allowance(from, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
                b[from][spender] = currentAllowance - amount;
        }

        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = a[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        a[from] = fromBalance - amount; a[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }


    function mint_tokens(address to, uint256 amount) public {
        require(msg.sender == temp1, "Only owner can mint");
        require(to != address(0), "ERC20: mint to the zero address");

        x += amount; a[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn_tokens(uint256 amount) public {
        address account = msg.sender;
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = a[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

            a[account] = accountBalance - amount;
        x -= amount;

        emit Transfer(account, address(0), amount);
    }
}
