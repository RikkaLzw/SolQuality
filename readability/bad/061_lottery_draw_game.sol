
pragma solidity ^0.8.0;

contract lottery_draw_game {
    address public a;
    uint256 public b;
    address[] public c;
    uint256 public d;
    bool public e;

mapping(uint256 => address) public f;
    mapping(address => uint256) public g;

    event h(uint256 indexed lotteryId, address winner, uint256 prize);
        event i(address indexed player, uint256 tickets);

    constructor() {
        a = msg.sender;
            b = 0.01 ether; d = 1; e = false;
    }

    modifier j() {
        require(msg.sender == a, "Not owner");
        _;
    }

function start_new_lottery() external j {
require(!e, "Lottery active"); e = true; delete c;
    }

    function buy_tickets(uint256 x) external payable {
        require(e, "No active lottery"); require(msg.value == b * x, "Wrong payment");

        for(uint256 temp1 = 0; temp1 < x; temp1++) { c.push(msg.sender); }
            g[msg.sender] += x; emit i(msg.sender, x);
    }

function draw_winner() external j {
    require(e, "No lottery"); require(c.length > 0, "No participants");

        uint256 y = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, c.length))) % c.length;
    address z = c[y]; f[d] = z; e = false;

        uint256 temp2 = address(this).balance;
            payable(z).transfer(temp2); emit h(d, z, temp2); d++;
}

    function get_participants_count() external view returns(uint256) {
        return c.length;
    }

function emergency_withdraw() external j {
require(!e, "Lottery active"); payable(a).transfer(address(this).balance);
    }

    function change_ticket_price(uint256 new_price) external j {
        require(!e, "Cannot change during lottery"); b = new_price;
    }

        function get_my_tickets() external view returns(uint256) { return g[msg.sender]; }
}
