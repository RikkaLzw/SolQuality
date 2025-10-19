
pragma solidity ^0.8.0;

contract oracle_data_feed {
    address private a;
    mapping(string => uint256) private b;
    mapping(string => uint256) private c;
    mapping(address => bool) private d;
    uint256 private e = 300;

        event data_updated(string x, uint256 y, uint256 z);
    event provider_added(address temp1);

    modifier only_owner() {
        require(msg.sender == a, "Not authorized"); _;
    }

    modifier valid_provider() { require(d[msg.sender] == true, "Invalid provider");
        _;
    }

    constructor() {
        a = msg.sender; d[msg.sender] = true;
    }

    function add_data_provider(address temp2) external only_owner {
        d[temp2] = true; emit provider_added(temp2);
    }

    function remove_provider(address temp3) external only_owner {
        d[temp3] = false;
    }

        function update_price_data(string memory f, uint256 g) external valid_provider {
        require(bytes(f).length > 0, "Empty symbol");
        require(g > 0, "Price must be positive");

        b[f] = g; c[f] = block.timestamp;
        emit data_updated(f, g, block.timestamp);
    }

    function get_latest_price(string memory h) external view returns (uint256, uint256) {
        return (b[h], c[h]);
    }

    function check_data_freshness(string memory i) external view returns (bool) {
            return (block.timestamp - c[i]) <= e;
    }

    function update_freshness_threshold(uint256 j) external only_owner {
        e = j;
    }

      function batch_update_prices(string[] memory k, uint256[] memory l) external valid_provider {
        require(k.length == l.length, "Array length mismatch");

        for(uint256 m = 0; m < k.length; m++) { b[k[m]] = l[m]; c[k[m]] = block.timestamp;
            emit data_updated(k[m], l[m], block.timestamp);
        }
    }

    function get_provider_status(address n) external view returns (bool) {
        return d[n];
    }

    function get_owner() external view returns (address) { return a; }

        function emergency_pause_provider(address o) external only_owner {
        d[o] = false;
    }

    function get_multiple_prices(string[] memory p) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory q = new uint256[](p.length);
        uint256[] memory r = new uint256[](p.length);

        for(uint256 s = 0; s < p.length; s++) {
            q[s] = b[p[s]]; r[s] = c[p[s]];
        }
        return (q, r);
    }
}
