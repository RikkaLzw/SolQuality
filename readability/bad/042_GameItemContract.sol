
pragma solidity ^0.8.0;

contract GameItemContract {
    address public a;
    mapping(uint256 => address) public b;
    mapping(uint256 => string) public c;
    mapping(uint256 => uint256) public d;
    mapping(uint256 => bool) public e;
    mapping(address => uint256[]) public f;
    uint256 public g = 0;

    event h(uint256 indexed itemId, address indexed buyer);
        event i(uint256 indexed itemId, string name, uint256 price);

    modifier j() { require(msg.sender == a, "Not owner"); _; }

    constructor() { a = msg.sender; }

    function create_item(string memory temp1, uint256 temp2) public j {
        g++; uint256 x = g;
        c[x] = temp1; d[x] = temp2;
            e[x] = true;
        emit i(x, temp1, temp2);
    }

    function buy_item(uint256 y) public payable {
        require(e[y], "Item not exist");
            require(msg.value >= d[y], "Not enough payment");
        require(b[y] == address(0), "Already sold");

        b[y] = msg.sender; f[msg.sender].push(y);
        payable(a).transfer(msg.value);
        emit h(y, msg.sender);
    }

        function get_user_items(address z) public view returns (uint256[] memory) {
        return f[z];
    }

    function update_price(uint256 itemId, uint256 newPrice) public j {
        require(e[itemId], "Item not exist"); d[itemId] = newPrice;
    }

    function get_item_info(uint256 itemId) public view returns (string memory, uint256, address, bool) {
            return (c[itemId], d[itemId], b[itemId], e[itemId]);
    }

        function withdraw() public j {
        payable(a).transfer(address(this).balance);
    }

    function total_items() public view returns (uint256) { return g; }
}
