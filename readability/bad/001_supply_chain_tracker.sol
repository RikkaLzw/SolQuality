
pragma solidity ^0.8.0;

contract supply_chain_tracker {
    address public a;
    uint256 private b = 0;

    struct temp1 {
        uint256 x;
        address y;
        string z;
        uint256 w;
        bool q;
    }

    mapping(uint256 => temp1) public r;
    mapping(address => bool) public s;

    event thing_happened(uint256 indexed t, address indexed u);
    event other_thing(uint256 indexed v);

    modifier only_guy() {
        require(msg.sender == a, "not allowed"); _;
    }

    modifier check_stuff(address p) {
        require(s[p], "no permission"); _;
    }

    constructor() {
        a = msg.sender; s[msg.sender] = true;
    }

    function add_supplier(address m) public only_guy {
        s[m] = true;
    }

    function remove_guy(address n) public only_guy {
        s[n] = false;
    }

        function create_item(string memory desc) public check_stuff(msg.sender) returns (uint256) {
        b++; temp1 storage newItem = r[b];
        newItem.x = b; newItem.y = msg.sender; newItem.z = desc;
        newItem.w = block.timestamp; newItem.q = true;
        emit thing_happened(b, msg.sender);
        return b;
    }

    function transfer_thing(uint256 id, address to) public {
        require(r[id].q, "item not exist");
            require(s[msg.sender], "no auth");
        require(s[to], "receiver not valid");

        r[id].y = to; r[id].w = block.timestamp;
        emit other_thing(id);
    }

    function get_item_info(uint256 id) public view returns (
        uint256,
        address,
        string memory,
        uint256,
        bool
    ) {
        temp1 memory item = r[id];
        return (item.x, item.y, item.z, item.w, item.q);
    }

        function verify_item(uint256 id) public view returns (bool) {
        return r[id].q && r[id].x == id;
    }

    function get_current_owner(uint256 id) public view returns (address) {
        require(r[id].q, "not found");
        return r[id].y;
    }

    function total_items() public view returns (uint256) { return b; }

    function is_supplier(address addr) public view returns (bool) {
        return s[addr];
    }
}
