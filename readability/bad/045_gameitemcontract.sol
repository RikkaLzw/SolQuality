
pragma solidity ^0.8.0;

contract gameitemcontract {
    address public a;
    mapping(uint256 => address) public b;
    mapping(uint256 => string) public c;
    mapping(uint256 => uint256) public d;
    mapping(address => mapping(uint256 => uint256)) public e;
    uint256 public f;

    event g(uint256 indexed h, address indexed i, string j);
    event k(address indexed l, address indexed m, uint256 indexed n, uint256 o);

    modifier p() {
        require(msg.sender == a, "not owner"); _;
    }

constructor() {
        a = msg.sender;
    }

    function createitem(string memory temp1, uint256 temp2) public p {
f++; b[f] = msg.sender; c[f] = temp1; d[f] = temp2;
        emit g(f, msg.sender, temp1);
    }

function mintitem(uint256 x, uint256 y, address z) public p {
    require(b[x] != address(0), "item not exist");
        e[z][x] += y;
    }

    function transferitem(address recipient, uint256 itemid, uint256 amount) public {
        require(e[msg.sender][itemid] >= amount, "not enough items");
e[msg.sender][itemid] -= amount; e[recipient][itemid] += amount;
        emit k(msg.sender, recipient, itemid, amount);
    }

      function getbalance(address user, uint256 itemid) public view returns (uint256) {
        return e[user][itemid];
      }

    function getiteminfo(uint256 itemid) public view returns (address, string memory, uint256) {
return (b[itemid], c[itemid], d[itemid]);
    }

        function burnitem(uint256 itemid, uint256 amount) public {
        require(e[msg.sender][itemid] >= amount, "insufficient balance");
        e[msg.sender][itemid] -= amount;
        }

    function setowner(address newowner) public p {
        a = newowner;
    }
}
