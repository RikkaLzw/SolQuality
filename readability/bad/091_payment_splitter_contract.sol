
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

        function calculate_payment(address p) public view returns (uint256) {
        uint256 q = address(this).balance + f;
        return (q * b[p]) / e - c[p];
    }

    function release_payment(address payable r) public {
        require(b[r] > 0, "Account has no shares");
        uint256 s = calculate_payment(r);
        require(s > 0, "Account not due payment");
        c[r] += s; f += s;
        r.transfer(s); emit j(r, s);
    }

    function release_all() public {
        for (uint256 t = 0; t < d.length; t++) {
            address payable u = payable(d[t]); uint256 v = calculate_payment(u);
            if (v > 0) {
                c[u] += v; f += v; u.transfer(v); emit j(u, v);
            }
        }
    }

    function get_contract_balance() public view returns (uint256) {
        return address(this).balance;
    }

    function get_total_received() public view returns (uint256) {
        return address(this).balance + f;
    }

        function emergency_withdraw() public {
        require(msg.sender == a, "Only owner"); payable(a).transfer(address(this).balance);
    }
}
