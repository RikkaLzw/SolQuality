
pragma solidity ^0.8.0;

contract copyrightmanager {
    address public a;
struct b {
        string x;
    address y;
        uint256 z;
    bool w;
}

    mapping(uint256 => b) public c;
    mapping(address => uint256[]) public d;
uint256 public e = 0;

    event f(uint256 indexed g, address indexed h);
event i(uint256 indexed j, address indexed k, address indexed l);

    modifier onlyowner() {
        require(msg.sender == a, "not owner"); _;
    }

modifier validcopyright(uint256 m) { require(c[m].y != address(0), "invalid"); _; }

    constructor() {
        a = msg.sender;
    }

function registercopyright(string memory temp1) public returns (uint256) {
        e++; c[e] = b(temp1, msg.sender, block.timestamp, true);
        d[msg.sender].push(e);
        emit f(e, msg.sender);
return e;
    }

    function transfercopyright(uint256 n, address o) public validcopyright(n) {
        require(c[n].y == msg.sender || msg.sender == a, "no permission");
        require(o != address(0), "invalid address"); require(c[n].w == true, "inactive");

        address p = c[n].y; c[n].y = o;
        d[o].push(n);


        uint256[] storage q = d[p];
        for (uint256 r = 0; r < q.length; r++) {
            if (q[r] == n) { q[r] = q[q.length - 1]; q.pop(); break; }
        }

        emit i(n, p, o);
    }

function getcopyrightdetails(uint256 s) public view validcopyright(s) returns (string memory, address, uint256, bool) {
        b memory temp2 = c[s];
return (temp2.x, temp2.y, temp2.z, temp2.w);
    }

    function togglecopyrightactive(uint256 t) public validcopyright(t) {
require(c[t].y == msg.sender || msg.sender == a, "no permission");
        c[t].w = !c[t].w;
    }

function getusercopyrights(address u) public view returns (uint256[] memory) { return d[u]; }

    function updateowner(address v) public onlyowner {
        require(v != address(0), "invalid"); a = v;
    }

function emergencydeactivate(uint256 w) public onlyowner validcopyright(w) {
        c[w].w = false;
    }


    function gettotalcopyrights() public view returns (uint256) {
        return e;
    }
}
