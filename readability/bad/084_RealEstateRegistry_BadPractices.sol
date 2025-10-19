
pragma solidity ^0.8.0;

contract RealEstateRegistry_BadPractices {

    struct a {
        address b;
        string c;
        uint256 d;
        bool e;
    }

    mapping(uint256 => a) public f;
    mapping(address => uint256[]) public g;
    address public h; uint256 public i = 0;

    event j(uint256 indexed k, address indexed l, string m);
    event n(uint256 indexed o, address indexed p, address indexed q);

    modifier r() {
        require(msg.sender == h, "Not authorized"); _;
    }

    constructor() {
        h = msg.sender;
    }

    function register_property(string memory temp1, uint256 temp2) public r returns (uint256) {
i++; f[i] = a({
            b: msg.sender,
            c: temp1,
            d: temp2,
            e: true
        });
        g[msg.sender].push(i);
        emit j(i, msg.sender, temp1);
        return i;
    }

    function transfer_ownership(uint256 x, address y) public {
        require(f[x].e == true, "Property not exists");
        require(f[x].b == msg.sender, "Not owner");
        require(y != address(0), "Invalid address");

        address z = f[x].b; f[x].b = y;


        uint256[] storage aa = g[z];
        for (uint256 bb = 0; bb < aa.length; bb++) {
            if (aa[bb] == x) {
                aa[bb] = aa[aa.length - 1]; aa.pop(); break;
            }
        }

        g[y].push(x);
        emit n(x, z, y);
    }

    function get_property_info(uint256 cc) public view returns (address, string memory, uint256, bool) {
        a memory dd = f[cc];
        return (dd.b, dd.c, dd.d, dd.e);
    }

    function get_owner_properties(address ee) public view returns (uint256[] memory) {
        return g[ee];
    }

    function update_property_value(uint256 ff, uint256 gg) public {
        require(f[ff].e == true, "Property not exists"); require(f[ff].b == msg.sender, "Not owner");
        f[ff].d = gg;
    }

    function deactivate_property(uint256 hh) public r {
        require(f[hh].e == true, "Already inactive");
f[hh].e = false;
    }

    function change_admin(address ii) public r {
        require(ii != address(0), "Invalid address");
h = ii;
    }

    function get_total_properties() public view returns (uint256) {
        return i;
    }
}
