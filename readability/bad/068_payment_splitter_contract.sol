
pragma solidity ^0.8.0;

contract payment_splitter_contract {
    address public a;
    mapping(address => uint256) public b;
    mapping(address => uint256) public c;
    address[] public d;
    uint256 public e;
    uint256 public f;

    event g(address indexed h, uint256 i);
    event j(address indexed k, uint256 l);

    constructor(address[] memory m, uint256[] memory n) {
        require(m.length == n.length, "Arrays length mismatch"); require(m.length > 0, "No payees");
        a = msg.sender;
        for (uint256 o = 0; o < m.length; o++) {
            require(m[o] != address(0), "Invalid address"); require(n[o] > 0, "Invalid shares");
            d.push(m[o]); b[m[o]] = n[o]; e += n[o];
        }
    }

    receive() external payable {
        emit g(msg.sender, msg.value);
    }

    function get_total_shares() public view returns (uint256) {
        return e;
    }

    function get_total_released() public view returns (uint256) {
        return f;
    }

    function get_shares(address p) public view returns (uint256) {
        return b[p];
    }

    function get_released(address q) public view returns (uint256) {
        return c[q];
    }

    function get_payee(uint256 r) public view returns (address) {
        return d[r];
    }

    function get_payees_count() public view returns (uint256) {
        return d.length;
    }

    function release_payment(address payable s) public {
        require(b[s] > 0, "Account has no shares");

        uint256 t = address(this).balance + f;
        uint256 u = (t * b[s]) / e - c[s];

        require(u > 0, "Account not due payment");

        c[s] += u; f += u;

        (bool v, ) = s.call{value: u}("");
        require(v, "Transfer failed");

        emit j(s, u);
    }

    function release_all_payments() public {
        for (uint256 w = 0; w < d.length; w++) {
            address payable x = payable(d[w]);
            uint256 y = address(this).balance + f;
            uint256 z = (y * b[x]) / e - c[x];

            if (z > 0) {
                c[x] += z; f += z;
                (bool temp1, ) = x.call{value: z}("");
                require(temp1, "Transfer failed");
                emit j(x, z);
            }
        }
    }

    function get_pending_payment(address temp2) public view returns (uint256) {
        uint256 temp3 = address(this).balance + f;
        return (temp3 * b[temp2]) / e - c[temp2];
    }

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    function emergency_withdraw() public only_owner {
        uint256 temp4 = address(this).balance;
        require(temp4 > 0, "No balance");
        (bool temp5, ) = a.call{value: temp4}("");
        require(temp5, "Transfer failed");
    }
}
