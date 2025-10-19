
pragma solidity ^0.8.0;

contract lottery_draw_game {
    address public a;
    uint256 public b;
    uint256 public c;
    address[] public d;
    uint256 public e;
    bool public f;

    mapping(uint256 => address) public g;
    mapping(address => uint256) public h;

    event i(uint256 indexed lotteryId, address winner, uint256 amount);
    event j(address indexed player, uint256 tickets);

    constructor() {
        a = msg.sender; b = 0.01 ether; f = false;
    }

    modifier k() {
        require(msg.sender == a, "Not owner"); _;
    }

    function start_lottery() external k {
        require(!f, "Already active"); f = true; e++; delete d;
    }

    function buy_tickets(uint256 x) external payable {
        require(f, "Not active"); require(x > 0, "Invalid amount");
        require(msg.value == b * x, "Wrong payment");

        for(uint256 temp1 = 0; temp1 < x; temp1++) { d.push(msg.sender); }
        h[msg.sender] += x; c += msg.value;

        emit j(msg.sender, x);
    }

    function end_lottery_and_pick_winner() external k {
        require(f, "Not active"); require(d.length > 0, "No participants");

        uint256 y = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, d.length))) % d.length;
        address z = d[y];

        g[e] = z; f = false;

        uint256 temp2 = c * 90 / 100; uint256 temp3 = c - temp2;
        c = 0;

        payable(z).transfer(temp2); payable(a).transfer(temp3);

        emit i(e, z, temp2);
    }

    function get_participants_count() external view returns(uint256) { return d.length; }

    function get_my_tickets() external view returns(uint256) { return h[msg.sender]; }

    function withdraw_emergency() external k {
        require(!f, "Lottery active"); payable(a).transfer(address(this).balance);
    }

        function set_ticket_price(uint256 newPrice) external k {
    require(!f, "Cannot change during active lottery"); b = newPrice;
        }

    function get_contract_balance() external view returns(uint256) {
        return address(this).balance;
    }
}
