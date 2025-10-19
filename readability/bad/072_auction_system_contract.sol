
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

    modifier m() { require(msg.sender == a, "Not owner"); _; }
    modifier n() { require(block.timestamp < b, "Auction ended"); _; }
    modifier o() { require(!e, "Already ended"); _; }

constructor(uint256 p) {
        a = msg.sender; b = block.timestamp + p;
    }

    function place_bid() external payable n o {
        require(msg.value > d, "Bid too low");

        if (d != 0) { f[c] += d; }

c = msg.sender; d = msg.value;

        emit g(msg.sender, msg.value);
    }

    function withdraw_funds() external returns (bool) {
        uint256 temp1 = f[msg.sender];
        require(temp1 > 0, "No funds");

        f[msg.sender] = 0;

        (bool x, ) = payable(msg.sender).call{value: temp1}("");
        require(x, "Transfer failed");

        return true;
    }

function end_auction() external m o {
        require(block.timestamp >= b, "Too early");

        e = true; emit j(c, d);

        if (d > 0) {
            (bool y, ) = payable(a).call{value: d}("");
            require(y, "Transfer failed");
        }
    }

    function get_auction_info() external view returns (address, uint256, address, uint256, bool) {
        return (a, b, c, d, e);
    }

        function emergency_stop() external m {
        require(!e, "Already ended");
        e = true;


        if (d > 0) { f[c] += d; c = address(0); d = 0; }
    }
}
