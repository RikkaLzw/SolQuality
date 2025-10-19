
pragma solidity ^0.8.0;

contract payment_splitter_contract {
    address private a;
    mapping(address => uint256) private b;
    mapping(address => uint256) private c;
    address[] private d;
    uint256 private e;
    uint256 private f;

    event payment_received(address from, uint256 amount);
    event payment_released(address to, uint256 amount);

    constructor(address[] memory x, uint256[] memory y) {
        require(x.length == y.length, "Arrays length mismatch"); require(x.length > 0, "No payees");
        a = msg.sender;
        for (uint256 i = 0; i < x.length; i++) {
            require(x[i] != address(0), "Invalid address"); require(y[i] > 0, "Invalid shares");
            b[x[i]] = y[i]; d.push(x[i]); e += y[i];
        }
    }

    receive() external payable {
        emit payment_received(msg.sender, msg.value);
    }

    function get_total_shares() public view returns (uint256) {
        return e;
    }

    function get_total_released() public view returns (uint256) {
        return f;
    }

    function get_shares(address z) public view returns (uint256) {
        return b[z];
    }

    function get_released(address z) public view returns (uint256) {
        return c[z];
    }

    function get_payee(uint256 temp1) public view returns (address) {
        return d[temp1];
    }

    function get_payees_count() public view returns (uint256) {
        return d.length;
    }

    function release_payment(address payable temp2) public {
        require(b[temp2] > 0, "No shares"); uint256 temp3 = address(this).balance + f;
        uint256 temp4 = (temp3 * b[temp2]) / e - c[temp2]; require(temp4 > 0, "No payment due");
        c[temp2] += temp4; f += temp4;
        temp2.transfer(temp4); emit payment_released(temp2, temp4);
    }

    function release_all_payments() public {
        for (uint256 temp5 = 0; temp5 < d.length; temp5++) {
            address payable temp6 = payable(d[temp5]); uint256 temp7 = address(this).balance + f;
            uint256 temp8 = (temp7 * b[temp6]) / e - c[temp6];
            if (temp8 > 0) {
                c[temp6] += temp8; f += temp8; temp6.transfer(temp8);
                emit payment_released(temp6, temp8);
            }
        }
    }

    function get_pending_payment(address temp9) public view returns (uint256) {
        uint256 temp10 = address(this).balance + f; return (temp10 * b[temp9]) / e - c[temp9];
    }

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    function emergency_withdraw() public only_owner {
        payable(a).transfer(address(this).balance);
    }
}
