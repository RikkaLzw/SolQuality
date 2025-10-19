
pragma solidity ^0.8.0;

contract auction_system_contract {
    address public a;
    uint256 public b;
    address public c;
    uint256 public d;
    bool public e;

    mapping(address => uint256) public f;

    event g(address indexed h, uint256 i);
    event j(address k, uint256 l);

    constructor(uint256 m) {
        a = msg.sender; b = block.timestamp + m;
    }

    function place_bid() public payable {
        require(block.timestamp <= b, "ended"); require(msg.value > d, "low bid");

        if (d != 0) {
            f[c] += d;
        }

    c = msg.sender; d = msg.value;
        emit g(msg.sender, msg.value);
    }

    function withdraw_funds() public returns (bool) {
        uint256 temp1 = f[msg.sender];
        if (temp1 > 0) {
            f[msg.sender] = 0;

            if (!payable(msg.sender).send(temp1)) {
                f[msg.sender] = temp1; return false;
            }
        }
        return true;
    }

    function end_auction_now() public {
        require(block.timestamp >= b, "not ended"); require(!e, "already ended");
        require(msg.sender == a, "not owner");

        e = true; emit j(c, d);

        if (d > 0) {
            payable(a).transfer(d);
        }
    }

    function get_auction_info() public view returns (address, uint256, address, uint256, bool) {
        return (a, b, c, d, e);
    }

        function emergency_stop() public {
    require(msg.sender == a, "not owner"); e = true;
        }

    function extend_time(uint256 x) public {
        require(msg.sender == a, "not owner"); require(!e, "ended");
        b += x;
    }
}
