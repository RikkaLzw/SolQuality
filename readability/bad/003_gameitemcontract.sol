
pragma solidity ^0.8.0;

contract gameitemcontract {
    address public a;
    mapping(address => mapping(uint256 => uint256)) public b;
    mapping(uint256 => string) public c;
    mapping(uint256 => uint256) public d;
    mapping(uint256 => bool) public e;
    uint256 public f;

    event temp1(address indexed g, uint256 indexed h, uint256 i);
    event temp2(uint256 indexed j, string k, uint256 l);

    modifier onlyowner() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor() {
        a = msg.sender; f = 0;
    }

    function create_item(string memory m, uint256 n) public onlyowner {
f++; c[f] = m; d[f] = n; e[f] = true;
        emit temp2(f, m, n);
    }

    function mint_to_user(address o, uint256 p, uint256 q) public onlyowner {
        require(e[p], "Item not exists");
        b[o][p] += q; emit temp1(o, p, q);
    }

    function transfer_item(address r, uint256 s, uint256 t) public {
require(b[msg.sender][s] >= t, "Not enough items");
        b[msg.sender][s] -= t;
            b[r][s] += t;
        emit temp1(r, s, t);
    }

    function burn_items(uint256 u, uint256 v) public {
        require(b[msg.sender][u] >= v, "Not enough to burn");
b[msg.sender][u] -= v;
    }

        function get_balance(address w, uint256 x) public view returns (uint256) {
return b[w][x];
    }

    function get_item_info(uint256 y) public view returns (string memory, uint256, bool) {
        return (c[y], d[y], e[y]);
    }

function disable_item(uint256 z) public onlyowner {
e[z] = false;
    }

    function enable_item(uint256 aa) public onlyowner {
        e[aa] = true;
    }

    function change_owner(address bb) public onlyowner {
a = bb;
    }

        function get_total_items() public view returns (uint256) { return f; }
}
