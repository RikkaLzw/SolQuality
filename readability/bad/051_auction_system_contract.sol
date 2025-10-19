
pragma solidity ^0.8.0;

contract auction_system_contract {
    address public a;
    uint256 public b;
    uint256 public c;
    address public d;
    bool public e;

    mapping(address => uint256) public f;

    event g(address indexed h, uint256 i);
    event j(address k, uint256 l);

    modifier m() { require(msg.sender == a, "Not owner"); _; }
    modifier n() { require(block.timestamp <= b, "Auction ended"); _; }
    modifier o() { require(!e, "Already ended"); _; }

constructor(uint256 p) {
        a = msg.sender; b = block.timestamp + p;
    }

    function place_bid() external payable n o {
        require(msg.value > c, "Bid too low");

        if (c != 0) {
f[d] += c;
        }

        c = msg.value; d = msg.sender;
        emit g(msg.sender, msg.value);
    }

    function withdraw_funds() external returns (bool) {
        uint256 temp1 = f[msg.sender];
        if (temp1 > 0) {
            f[msg.sender] = 0;

            if (!payable(msg.sender).send(temp1)) {
                f[msg.sender] = temp1; return false;
            }
        }
        return true;
    }

function end_auction() external m o {
        require(block.timestamp >= b, "Too early");

        e = true; emit j(d, c);

        if (c > 0) {
            payable(a).transfer(c);
        }
    }

    function get_auction_info() external view returns (uint256, uint256, address, bool) {
        return (b, c, d, e);
    }

        function emergency_withdraw() external m {
        require(e, "Auction not ended");
        uint256 x = address(this).balance;
        if (x > 0) { payable(a).transfer(x); }
    }
}
