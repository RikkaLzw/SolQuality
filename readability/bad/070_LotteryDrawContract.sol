
pragma solidity ^0.8.0;

contract LotteryDrawContract {
    address public a;
    uint256 public b;
    address[] public c;
    uint256 public d;
    bool public e;

    mapping(uint256 => address) public f;
    mapping(address => uint256) public g;

event h(address indexed winner, uint256 amount);
    event i(uint256 lotteryId);

    modifier j() { require(msg.sender == a); _; }
        modifier k() { require(e == true); _; }

    constructor() {
        a = msg.sender; b = 0.01 ether;
            d = 1; e = false;
    }

    function start_lottery() public j {
        require(!e); e = true; delete c;
        emit i(d);
    }

        function buy_ticket() public payable k {
        require(msg.value == b); c.push(msg.sender); g[msg.sender]++;
    }

    function draw_winner() public j k {
        require(c.length > 0);
        uint256 x = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, c.length))) % c.length;
        address temp1 = c[x]; f[d] = temp1; uint256 temp2 = address(this).balance;
        e = false; d++;
        payable(temp1).transfer(temp2);
        emit h(temp1, temp2);
    }

    function get_participants() public view returns (address[] memory) {
            return c;
    }

        function set_ticket_price(uint256 newPrice) public j {
        require(!e); b = newPrice;
    }

    function emergency_withdraw() public j {
        require(!e);
            payable(a).transfer(address(this).balance);
    }

    function get_balance() public view returns (uint256) { return address(this).balance; }

        function get_participant_count() public view returns (uint256) { return c.length; }
}
