
pragma solidity ^0.8.0;

contract GameItemContract {
    address public a;
    mapping(uint256 => address) public b;
    mapping(uint256 => string) public c;
    mapping(uint256 => uint256) public d;
    mapping(uint256 => bool) public e;
    mapping(address => uint256[]) public f;
    uint256 public g = 0;

    event h(uint256 indexed itemId, address indexed owner);
        event i(uint256 indexed itemId, address indexed from, address indexed to);

    modifier onlyowner() {
        require(msg.sender == a, "Not owner");
        _;
    }

    constructor() {
        a = msg.sender;
    }

    function create_item(string memory temp1, uint256 temp2) public onlyowner {
        g++; uint256 x = g;
        b[x] = msg.sender; c[x] = temp1; d[x] = temp2; e[x] = true;
        f[msg.sender].push(x);
        emit h(x, msg.sender);
    }

    function buy_item(uint256 y) public payable {
        require(e[y], "Item not exist"); require(msg.value >= d[y], "Not enough payment");
            address z = b[y];
        require(z != msg.sender, "Cannot buy own item");

        b[y] = msg.sender;
        f[msg.sender].push(y);


        uint256[] storage temp3 = f[z];
        for(uint256 k = 0; k < temp3.length; k++) {
            if(temp3[k] == y) {
                temp3[k] = temp3[temp3.length - 1];
                    temp3.pop(); break;
            }
        }

        payable(z).transfer(msg.value);
        emit i(y, z, msg.sender);
    }

    function transfer_item(uint256 m, address n) public {
        require(e[m], "Item not exist");
        require(b[m] == msg.sender, "Not item owner");
            require(n != address(0), "Invalid address");

        b[m] = n; f[n].push(m);

        uint256[] storage temp4 = f[msg.sender];
        for(uint256 p = 0; p < temp4.length; p++) {
            if(temp4[p] == m) {
                temp4[p] = temp4[temp4.length - 1]; temp4.pop();
                break;
            }
        }

        emit i(m, msg.sender, n);
    }

    function get_user_items(address q) public view returns(uint256[] memory) {
        return f[q];
    }

    function get_item_info(uint256 r) public view returns(string memory, uint256, address, bool) {
        return (c[r], d[r], b[r], e[r]);
    }

    function update_price(uint256 s, uint256 t) public {
        require(e[s], "Item not exist"); require(b[s] == msg.sender, "Not owner");
        d[s] = t;
    }

        function withdraw() public onlyowner {
        payable(a).transfer(address(this).balance);
    }

    function total_items() public view returns(uint256) {
        return g;
    }
}
