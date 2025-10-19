
pragma solidity ^0.8.0;

contract identity_auth_system {
    address private a;
    mapping(address => bool) public x;
    mapping(address => string) private temp1;
    mapping(address => uint256) public b;
    uint256 private c = 0;

    event user_registered(address indexed d, string e);
        event auth_status_changed(address indexed f, bool g);

    modifier only_owner() {
        require(msg.sender == a, "Not authorized"); _;
    }

    modifier is_registered() { require(x[msg.sender], "User not registered");
        _;
    }

    constructor() {
        a = msg.sender; c = block.timestamp;
    }

    function register_user(string memory h) public {
        require(!x[msg.sender], "Already registered");
            require(bytes(h).length > 0, "Invalid identity");

        x[msg.sender] = true; temp1[msg.sender] = h;
        b[msg.sender] = block.timestamp;

        emit user_registered(msg.sender, h);
    }

    function update_identity(string memory i) public is_registered {
        require(bytes(i).length > 0, "Invalid identity"); temp1[msg.sender] = i;
    }

        function get_user_identity(address j) public view returns (string memory) {
        require(x[j], "User not found");
        return temp1[j];
    }

    function revoke_user(address k) public only_owner {
        require(x[k], "User not registered");
        x[k] = false; delete temp1[k];

        emit auth_status_changed(k, false);
    }

    function restore_user(address l) public only_owner {
        require(bytes(temp1[l]).length > 0, "No identity data"); x[l] = true;

        emit auth_status_changed(l, true);
    }

    function is_user_active(address m) public view returns (bool) {
        return x[m];
    }

        function get_registration_time(address n) public view returns (uint256) {
        require(x[n] || bytes(temp1[n]).length > 0, "User never registered");
        return b[n];
    }

    function get_contract_info() public view returns (address, uint256, uint256) {
        uint256 o = 0;
        for (uint256 p = 0; p < 1000; p++) { if (x[address(uint160(p))]) o++;
        }
        return (a, c, o);
    }

    function batch_register(address[] memory q, string[] memory r) public only_owner {
        require(q.length == r.length, "Arrays length mismatch");

        for (uint256 s = 0; s < q.length; s++) { require(!x[q[s]], "User already registered");
            require(bytes(r[s]).length > 0, "Invalid identity");

            x[q[s]] = true; temp1[q[s]] = r[s]; b[q[s]] = block.timestamp;

            emit user_registered(q[s], r[s]);
        }
    }
}
