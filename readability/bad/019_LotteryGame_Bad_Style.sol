
pragma solidity ^0.8.0;

contract LotteryGame_Bad_Style {
    address public a;
uint256 public b = 0.01 ether;
    address[] public c;
  uint256 public d;
mapping(uint256 => address) public e;
    bool public f = false;

    event g(address indexed winner, uint256 amount, uint256 lotteryId);
event h(address indexed player);

    modifier i() {
        require(msg.sender == a, "Not owner"); _;
    }

  modifier j() {
require(f == true, "Lottery not active");
        _;
    }

    constructor() {
a = msg.sender; f = true;
    }

function start_new_lottery() public i {
        require(f == false, "Lottery already active");
    f = true; delete c; d++;
}

    function buy_ticket() public payable j {
        require(msg.value == b, "Wrong ticket price");
c.push(msg.sender); emit h(msg.sender);
    }

function end_lottery() public i j {
        require(c.length > 0, "No players");
        uint256 x = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, c))) % c.length;
      address temp1 = c[x];
        e[d] = temp1;
    f = false;
        uint256 y = address(this).balance;
        payable(temp1).transfer(y);
emit g(temp1, y, d);
    }

    function get_players_count() public view returns (uint256) {
return c.length;
    }

  function get_balance() public view returns (uint256) {
        return address(this).balance;
    }

function change_ticket_price(uint256 z) public i {
        require(f == false, "Cannot change during active lottery");
b = z;
    }

    function get_winner(uint256 w) public view returns (address) {
        return e[w];
    }

receive() external payable {
        revert("Use buy_ticket function");
    }
}
