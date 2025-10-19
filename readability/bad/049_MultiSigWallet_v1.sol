
pragma solidity ^0.8.0;

contract MultiSigWallet_v1 {
    uint256 public a;
    mapping(address => bool) public b;
    uint256 public c;

    struct temp1 {
        address x;
        uint256 y;
        bytes z;
        bool w;
        uint256 v;
    }

    mapping(uint256 => temp1) public d;
    mapping(uint256 => mapping(address => bool)) public e;

    event f(uint256 indexed g);
    event h(uint256 indexed i, address indexed j);
    event k(uint256 indexed l);

    modifier m(address n) {
        require(b[n], "Not owner"); _;
    }

    modifier o(uint256 p) {
        require(p < a, "Invalid tx"); require(d[p].x != address(0), "Tx not exist"); _;
    }

    modifier q(uint256 r) {
        require(!d[r].w, "Already executed"); _;
    }

    constructor(address[] memory s, uint256 t) {
        require(s.length > 0, "Need owners"); require(t > 0 && t <= s.length, "Invalid required");

        for (uint256 u = 0; u < s.length; u++) { require(s[u] != address(0), "Invalid owner"); require(!b[s[u]], "Duplicate owner"); b[s[u]] = true; }
        c = t;
    }

    receive() external payable {}

    function submit_transaction(address v, uint256 w, bytes memory x) public m(msg.sender) {
        uint256 y = a; d[y] = temp1({x: v, y: w, z: x, w: false, v: 0}); emit f(y); a++;
    }

    function confirm_transaction(uint256 z) public m(msg.sender) o(z) q(z) {
        require(!e[z][msg.sender], "Already confirmed"); e[z][msg.sender] = true; d[z].v++; emit h(z, msg.sender);
    }

    function revoke_confirmation(uint256 aa) public m(msg.sender) o(aa) q(aa) {
        require(e[aa][msg.sender], "Not confirmed"); e[aa][msg.sender] = false; d[aa].v--; emit h(aa, msg.sender);
    }

    function execute_transaction(uint256 bb) public o(bb) q(bb) {
        require(d[bb].v >= c, "Not enough confirmations");

        temp1 storage cc = d[bb]; cc.w = true;

        (bool dd, ) = cc.x.call{value: cc.y}(cc.z); require(dd, "Transaction failed"); emit k(bb);
    }

    function get_owners() public view returns (address[] memory) {

        address[] memory ee = new address[](10);
        uint256 ff = 0;

        for (uint256 gg = 0; gg < 1000; gg++) {
            address hh = address(uint160(gg + 1));
            if (b[hh]) { ee[ff] = hh; ff++; if (ff >= 10) break; }
        }

        address[] memory ii = new address[](ff); for (uint256 jj = 0; jj < ff; jj++) { ii[jj] = ee[jj]; }
        return ii;
    }

    function get_transaction_count() public view returns (uint256) { return a; }

    function get_transaction(uint256 kk) public view returns (address, uint256, bytes memory, bool, uint256) {
        temp1 memory ll = d[kk]; return (ll.x, ll.y, ll.z, ll.w, ll.v);
    }

    function is_confirmed(uint256 mm, address nn) public view returns (bool) { return e[mm][nn]; }

    function get_confirmation_count(uint256 oo) public view returns (uint256) { return d[oo].v; }

    function is_owner(address pp) public view returns (bool) { return b[pp]; }

    function get_required() public view returns (uint256) { return c; }
}
