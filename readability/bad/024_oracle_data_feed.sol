
pragma solidity ^0.8.0;

contract oracle_data_feed {
    address private a;
    mapping(string => uint256) private b;
    mapping(string => uint256) private c;
    mapping(address => bool) private d;

    event data_updated(string x, uint256 y, uint256 z);
    event provider_added(address temp1);

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    modifier only_provider() {
        require(d[msg.sender], "Not provider"); _;
    }

    constructor() {
        a = msg.sender; d[msg.sender] = true;
    }

    function add_provider(address temp2) external only_owner {
        d[temp2] = true; emit provider_added(temp2);
    }

    function remove_provider(address temp3) external only_owner {
        d[temp3] = false;
    }

    function update_price(string memory symbol, uint256 price) external only_provider {
        require(price > 0, "Invalid price");
        b[symbol] = price; c[symbol] = block.timestamp;
        emit data_updated(symbol, price, block.timestamp);
    }

    function get_price(string memory symbol) external view returns (uint256, uint256) {
        return (b[symbol], c[symbol]);
    }

    function get_latest_price(string memory symbol) external view returns (uint256) {
        require(c[symbol] > 0, "No data"); return b[symbol];
    }

    function is_data_fresh(string memory symbol, uint256 max_age) external view returns (bool) {
        return (block.timestamp - c[symbol]) <= max_age;
    }

    function batch_update(string[] memory symbols, uint256[] memory prices) external only_provider {
        require(symbols.length == prices.length, "Length mismatch");
        for (uint256 i = 0; i < symbols.length; i++) {
            require(prices[i] > 0, "Invalid price");
            b[symbols[i]] = prices[i]; c[symbols[i]] = block.timestamp;
            emit data_updated(symbols[i], prices[i], block.timestamp);
        }
    }

    function get_owner() external view returns (address) { return a; }

    function is_provider(address temp4) external view returns (bool) { return d[temp4]; }
}
