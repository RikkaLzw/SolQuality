
pragma solidity ^0.8.0;

contract payment_splitter_contract {
    address public a;
    mapping(address => uint256) public b;
    mapping(address => uint256) private c;
    address[] public d;
    uint256 public e;

        event f(address indexed g, uint256 h);
    event i(address indexed j, uint256 k);

    modifier onlyowner() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor(address[] memory temp1, uint256[] memory temp2) {
        require(temp1.length == temp2.length, "Arrays mismatch");
        require(temp1.length > 0, "Empty arrays");

        uint256 x = 0;
      for(uint256 y = 0; y < temp1.length; y++) {
            require(temp1[y] != address(0), "Zero address");
            require(temp2[y] > 0, "Zero share");
            b[temp1[y]] = temp2[y]; x += temp2[y];
        }
        d = temp1; e = x; a = msg.sender;
    }

    receive() external payable {
        emit f(msg.sender, msg.value);
    }

    function add_payee(address z, uint256 aa) external onlyowner {
        require(z != address(0), "Zero address");
        require(aa > 0, "Zero share");
        require(b[z] == 0, "Already exists");

        d.push(z);
            b[z] = aa; e += aa;
    }

    function remove_payee(address bb) external onlyowner {
        require(b[bb] > 0, "Not found");

        e -= b[bb]; b[bb] = 0;
        for(uint256 cc = 0; cc < d.length; cc++) {
            if(d[cc] == bb) {
                d[cc] = d[d.length - 1]; d.pop(); break;
            }
        }
    }

    function release_payment(address payable dd) external {
        require(b[dd] > 0, "No shares");

        uint256 ee = address(this).balance;
        uint256 ff = (ee * b[dd]) / e;
        uint256 gg = c[dd];

        require(ff > gg, "No payment due");

        uint256 hh = ff - gg;
        c[dd] = ff;

        (bool success, ) = dd.call{value: hh}("");
        require(success, "Transfer failed");

        emit i(dd, hh);
    }

    function get_pending_payment(address ii) external view returns(uint256) {
        if(b[ii] == 0) return 0;

        uint256 jj = address(this).balance;
        uint256 kk = (jj * b[ii]) / e;
        return kk > c[ii] ? kk - c[ii] : 0;
    }

        function get_payees() external view returns(address[] memory) { return d; }

    function get_shares(address ll) external view returns(uint256) { return b[ll]; }

    function get_released(address mm) external view returns(uint256) { return c[mm]; }

    function emergency_withdraw() external onlyowner {
        uint256 nn = address(this).balance;
        (bool success, ) = payable(a).call{value: nn}("");
        require(success, "Transfer failed");
    }
}
