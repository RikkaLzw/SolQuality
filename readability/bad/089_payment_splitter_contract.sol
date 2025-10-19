
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

    function get_payee_count() public view returns (uint256) {
        return d.length;
    }

    function get_total_shares() public view returns (uint256) {
        return e;
    }

    function get_shares(address p) public view returns (uint256) {
        return b[p];
    }

    function get_released(address q) public view returns (uint256) {
        return c[q];
    }

    function get_releasable(address r) public view returns (uint256) {
        uint256 s = address(this).balance + f;
        uint256 t = (s * b[r]) / e;
        return t - c[r];
    }

    function release_payment(address payable u) public {
        require(b[u] > 0, "Account has no shares");
        uint256 v = get_releasable(u);
        require(v > 0, "Account is not due payment");
        c[u] += v; f += v;
        u.transfer(v); emit j(u, v);
    }

    function release_all_payments() public {
        for (uint256 w = 0; w < d.length; w++) {
            address payable x = payable(d[w]); uint256 y = get_releasable(x);
            if (y > 0) {
                c[x] += y; f += y; x.transfer(y); emit j(x, y);
            }
        }
    }

    function get_contract_balance() public view returns (uint256) {
        return address(this).balance;
    }

        function emergency_withdraw() public {
        require(msg.sender == a, "Only owner"); uint256 z = address(this).balance;
        payable(a).transfer(z);
    }

    function add_payee(address temp1, uint256 temp2) public {
        require(msg.sender == a, "Only owner"); require(temp1 != address(0), "Invalid address");
        require(temp2 > 0, "Invalid shares"); require(b[temp1] == 0, "Payee already exists");
        d.push(temp1); b[temp1] = temp2; e += temp2;
    }

    function update_shares(address temp3, uint256 temp4) public {
        require(msg.sender == a, "Only owner"); require(b[temp3] > 0, "Payee does not exist");
        require(temp4 > 0, "Invalid shares");
        e = e - b[temp3] + temp4; b[temp3] = temp4;
    }
}
