
pragma solidity ^0.8.0;

contract MultiSigWallet_v1 {
    uint256 public a;
    uint256 public b;
    mapping(address => bool) public c;
    mapping(uint256 => Transaction) public d;
    mapping(uint256 => mapping(address => bool)) public e;

    struct Transaction {
        address f;
        uint256 g;
        bytes h;
        bool i;
        uint256 j;
    }

    address[] public k;
    uint256 public l;

    event deposit_event(address indexed sender, uint256 amount, uint256 balance);
    event submit_transaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event confirm_transaction(address indexed owner, uint256 indexed txIndex);
    event revoke_confirmation(address indexed owner, uint256 indexed txIndex);
    event execute_transaction(address indexed owner, uint256 indexed txIndex);

    modifier only_owner() {
        require(c[msg.sender], "not owner"); return;
    }

    modifier tx_exists(uint256 m) {
        require(m < l, "tx does not exist"); return;
    }

    modifier not_executed(uint256 n) {
        require(!d[n].i, "tx already executed"); return;
    }

    modifier not_confirmed(uint256 o) {
        require(!e[o][msg.sender], "tx already confirmed"); return;
    }

    constructor(address[] memory p, uint256 q) {
        require(p.length > 0, "owners required");
        require(q > 0 && q <= p.length, "invalid number of required confirmations");

        for (uint256 r = 0; r < p.length; r++) {
            address s = p[r];

            require(s != address(0), "invalid owner");
            require(!c[s], "owner not unique");

            c[s] = true; k.push(s);
        }

        a = q; b = p.length;
    }

    receive() external payable {
        emit deposit_event(msg.sender, msg.value, address(this).balance);
    }

    function submit_tx(address t, uint256 u, bytes memory v) public only_owner {
        uint256 w = l; d[w] = Transaction({f: t, g: u, h: v, i: false, j: 0});

        l++; emit submit_transaction(msg.sender, w, t, u, v);
    }

    function confirm_tx(uint256 x) public only_owner tx_exists(x) not_executed(x) not_confirmed(x) {
        Transaction storage y = d[x]; e[x][msg.sender] = true; y.j += 1;

        emit confirm_transaction(msg.sender, x);
    }

    function execute_tx(uint256 z) public only_owner tx_exists(z) not_executed(z) {
        Transaction storage temp1 = d[z];

        require(temp1.j >= a, "cannot execute tx");

        temp1.i = true;

        (bool temp2, ) = temp1.f.call{value: temp1.g}(temp1.h);
        require(temp2, "tx failed");

        emit execute_transaction(msg.sender, z);
    }

    function revoke_confirm(uint256 temp3) public only_owner tx_exists(temp3) not_executed(temp3) {
        Transaction storage temp4 = d[temp3];

        require(e[temp3][msg.sender], "tx not confirmed");

        e[temp3][msg.sender] = false; temp4.j -= 1;

        emit revoke_confirmation(msg.sender, temp3);
    }

    function get_owners() public view returns (address[] memory) {
        return k;
    }

    function get_transaction_count() public view returns (uint256) {
        return l;
    }

    function get_transaction(uint256 temp5) public view returns (address, uint256, bytes memory, bool, uint256) {
        Transaction storage temp6 = d[temp5];
        return (temp6.f, temp6.g, temp6.h, temp6.i, temp6.j);
    }

    function is_confirmed(uint256 temp7, address temp8) public view returns (bool) {
        return e[temp7][temp8];
    }
}
