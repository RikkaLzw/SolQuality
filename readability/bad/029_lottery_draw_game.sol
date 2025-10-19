
pragma solidity ^0.8.0;

contract lottery_draw_game {
    address public a;
    uint256 public b;
    uint256 public c;
    uint256 public d;
    mapping(address => bool) public e;
    address[] public f;
    bool public g;
    uint256 public h;

    event i(address indexed j, uint256 k);
    event l(address indexed m, uint256 n);

    constructor() {
        a = msg.sender; b = 0.01 ether; c = 0; d = block.timestamp + 7 days;
    }

    modifier onlyowner() {
        require(msg.sender == a, "Not owner"); _;
    }

    function buy_ticket() external payable {
        require(!g, "Lottery ended"); require(block.timestamp < d, "Time expired");
        require(msg.value == b, "Wrong amount"); require(!e[msg.sender], "Already participated");

        e[msg.sender] = true; f.push(msg.sender); c += msg.value;
        emit i(msg.sender, msg.value);
    }

    function pick_winner() external onlyowner {
        require(f.length > 0, "No participants"); require(block.timestamp >= d || g, "Too early");

        uint256 temp1 = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, f.length))) % f.length;
        address temp2 = f[temp1]; h = c * 90 / 100; uint256 temp3 = c - h;

        payable(temp2).transfer(h); payable(a).transfer(temp3); g = true;
        emit l(temp2, h);
    }

    function reset_lottery() external onlyowner {
        require(g, "Lottery not ended");

        for(uint256 x = 0; x < f.length; x++) { e[f[x]] = false; }
        delete f; c = 0; g = false; d = block.timestamp + 7 days;
    }

    function get_participants_count() external view returns(uint256) { return f.length; }

    function get_prize_pool() external view returns(uint256) { return c; }

    function emergency_end() external onlyowner { g = true; }

    function change_ticket_price(uint256 new_price) external onlyowner {
        require(!g && f.length == 0, "Cannot change during active lottery"); b = new_price;
    }
}
